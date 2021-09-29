use hex;
use openssl::hash::MessageDigest;
use openssl::stack::Stack;
use openssl::x509::store::X509StoreBuilder;
use openssl::x509::{X509VerifyResult, X509};
use std::io;
use std::io::Write;
use std::process::Command;
use std::time::Instant;
use std::{env, fs};
use x509_parser::pem::parse_x509_pem;

mod cert;
mod revocation;

mod errors;
use errors::Error;

pub fn parse_chain(
    chain: &mut Vec<X509>,
    _stapled_ocsp_response: Option<&[u8]>,
    check_ocsp: bool,
    staple: bool,
) -> Result<(), Error> {
    let mut translation_time = 0;
    let mut start = Instant::now();

    let mut counter = 0;
    let leaf = chain.remove(0);
    let leaf_der = leaf.to_der().unwrap();
    let cert = match cert::PrologCert::from_der(&leaf_der) {
        Ok(p) => p,
        Err(_) => {
            return Err(Error::X509ParsingError);
        }
    };
    let sha256 = hex::encode(leaf.digest(MessageDigest::sha256()).unwrap());
    let mut repr: String = format!("fingerprint(cert_0, \"{}\").\n", sha256.to_uppercase());

    repr.push_str(format!("{}\n\n", cert.emit_all(&format!("cert_{}", counter))).as_str());
    translation_time += start.elapsed().as_millis();

    let mut stack = Stack::new().unwrap();
    repr.push_str(
        get_intermediate_repr(&chain, &leaf, &mut stack, &mut counter, &mut translation_time)?.as_str(),
    );
    let mut store_builder = X509StoreBuilder::new().unwrap();

    // get root certs
    let separator = "-----END CERTIFICATE-----";
    let root_chain = fs::read_to_string("assets/roots.pem").unwrap();
    let mut found_issuer = false;
    if chain.len() == 0 {
        chain.push(leaf.clone());
    }
    for part in root_chain.split(separator) {
        if part.trim().is_empty() {
            continue;
        }

        let cert_pem = [part, separator].join("");
        let temp = parse_x509_pem(cert_pem.as_bytes()).unwrap().1.contents;
        let root_x509 = X509::from_der(&temp).unwrap();
        //println!("ROOT: {:?}", root_x509.subject_name());
        for intermediate_x509 in chain.iter() {
            if root_x509.issued(&intermediate_x509) == X509VerifyResult::OK {
                counter += 1;
                found_issuer = true;
                start = Instant::now();
                let root_x509_for_stack = X509::from_der(&temp).unwrap();
                stack.push(root_x509_for_stack).unwrap();
                repr.push_str(&format!(
                    "fingerprint(cert_{}, \"{}\").\n",
                    counter,
                    hex::encode(root_x509.digest(MessageDigest::sha256()).unwrap()).to_uppercase()
                ));
                let v = match cert::PrologCert::from_der(&temp) {
                    Ok(p) => p,
                    Err(_) => {
                        return Err(Error::X509ParsingError);
                    }
                };
                repr.push_str(&v.emit_all(&format!("cert_{}", counter)));
                repr.push_str(&format!(
                    "issuer(cert_{}, cert_{}).\n\n",
                    counter - 1,
                    counter
                ));
                translation_time += start.elapsed().as_millis();
            }
        }

        store_builder.add_cert(root_x509).unwrap();
    }
    if !found_issuer {
        eprintln!("NO ISSUER FOUND");
    }
    let store = store_builder.build();
    let subject_x509 = leaf;

    let mut subject_ref = subject_x509.as_ref();
    let mut cert_index = 0;
    for intermediate_ref in stack.iter() {
        let mut check_staple = staple;
        if cert_index != 0 {
            check_staple = false;
        }
        repr.push_str(&revocation::get_ocsp_fact(
            cert_index,
            &store,
            subject_ref,
            intermediate_ref,
            &stack,
            check_ocsp,
            check_staple,
        ));
        subject_ref = intermediate_ref;
        cert_index += 1;
    }
    println!("Translation time: {}ms", translation_time);

    match emit_chain_repr(&repr) {
        Ok(()) => Ok(()),
        Err(_) => Err(Error::UnknownError),
    }
}

pub fn verify_chain(client: &str, dns_name: &str) -> Result<(), Error> {
    let start = Instant::now();
    let status = Command::new("sh")
        .arg("-c")
        .arg(format!("prolog/run.sh {} {}", client, dns_name))
        .status()
        .expect("failed to execute process");

    let status = status.code().unwrap();
    println!("Verification time: {}ms", start.elapsed().as_millis());
    match status {
        0 => Ok(()),
        10 => Err(Error::CertNotTimeValid),
        20 => Err(Error::NameConstraintViolation),
        30 => Err(Error::CertNotValidForName),
        40 => Err(Error::CertRevoked),
        50 => Err(Error::PathLenConstraintViolated),
        60 => Err(Error::UnknownIssuer),
        70 => Err(Error::ACCFailure),
        80 => Err(Error::LeafValidForTooLong),
        _ => Err(Error::UnknownError),
    }
}

fn get_intermediate_repr(
    chain: &Vec<X509>,
    leaf: &X509,
    stack: &mut Stack<X509>,
    counter: &mut u32,
    translation_time: &mut u128,
) -> Result<String, Error> {
    let mut repr: String = "".to_string();
    let mut recursive_subject = leaf.clone();
    for intermediate_x509 in chain.iter() {
        *counter += 1;
        match recursive_subject.verify(&intermediate_x509.public_key().unwrap()) {
            Ok(true) => {}
            Ok(false) => return Err(Error::OpenSSLInvalid),
            Err(e) => {
                eprintln!("OpenSSL Verify error {}", e);
                return Err(Error::OpenSSLFailed);
            }
        }
        let start = Instant::now();
        recursive_subject = intermediate_x509.clone();

        let intermediate_der = intermediate_x509.to_der().unwrap();
        let intermediate = match cert::PrologCert::from_der(&intermediate_der) {
            Ok(p) => p,
            Err(_) => {
                return Err(Error::X509ParsingError);
            }
        };
        repr.push_str(&format!(
            "fingerprint(cert_{}, \"{}\").\n",
            counter,
            hex::encode(intermediate_x509.digest(MessageDigest::sha256()).unwrap()).to_uppercase()
        ));
        repr.push_str(&intermediate.emit_all(&format!("cert_{}", counter)));
        repr.push_str(&format!(
            "issuer(cert_{}, cert_{}).\n\n",
            *counter - 1,
            counter
        ));
        stack.push(intermediate_x509.clone()).unwrap();
        // We just assume (for now) that intermediates
        // do not have stapled ocsp responses.
        *translation_time += start.elapsed().as_millis();
    }
    return Ok(repr);
}

fn emit_chain_repr(repr: &str) -> io::Result<()> {
    let preamble = format!(
        "
:- module(certs, [
    basicConstraintsCritical/2,
    basicConstraintsExt/2,
    certificatePolicies/2,
    certificatePoliciesCritical/2,
    certificatePoliciesExt/2,
    commonName/2,
    extendedKeyUsage/2,
    extendedKeyUsageCritical/2,
    extendedKeyUsageExt/2,
    fingerprint/2,
    inhibitAnyPolicyExt/2,
    isCA/2,
    issuer/2,
    keyAlgorithm/2,
    keyLen/2,
    keyUsage/2,
    keyUsageCritical/2,
    keyUsageExt/2,
    nameConstraintsExt/2,
    notAfter/2,
    notBefore/2,
    pathLimit/2,
    policyConstraintsExt/2,
    policyMappingsExt/3,
    san/2,
    sanCritical/2,
    sanExt/2,
    serialNumber/2,
    signatureAlgorithm/2,
    subjectKeyIdentifier/2,
    subjectKeyIdentifierCritical/2,
    subjectKeyIdentifierExt/2,
    version/2,
    ocspResponse/2,
    stapledResponse/2
]).
:-style_check(-discontiguous).\n\n"
    );

    let jobindex = env::var("JOBINDEX").unwrap_or("".to_string());

    let outdir = format!("prolog/job{}", jobindex);
    fs::create_dir_all(&outdir)?;
    let filename = format!("{}/certs.pl", outdir);
    let mut certs_file = fs::File::create(filename)?;
    certs_file.write_all(preamble.as_bytes())?;
    certs_file.write_all(repr.as_bytes())?;
    certs_file.sync_all()
}
