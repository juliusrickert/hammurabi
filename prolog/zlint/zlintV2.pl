%:- use_module(std).
%:- use_module(certs).
%:- use_module(env).
:- use_module("prolog/job/certs").
%:- include(prolog/gen/job/std).
%:- include(prolog/gen/env).
:- include(public_suffix_list).

% includes zlint tests made into prolog rules

% check if Cert is a trusted root
isRoot(Cert):-
    certs:fingerprint(Cert, Fingerprint),
    trusted_roots(Fingerprint).

% Helper methods up here
% checks if cert is a root certificate
rootApplies(Cert) :-
	%certs:isCA(Cert, true),
	std:isRoot(Cert).
	%certs:fingerprint(Cert, Fingerprint),
    %trusted_roots(Fingerprint).

isSubCA(Cert) :-
	certs:isCA(Cert, true),
	\+isRoot(Cert).

% check for if it is a subscriber certificate
isSubCert(Cert) :-
	certs:isCA(Cert, false).

 
%  Root CA and Subordinate CA Certificate: 
%  keyUsage extension MUST be present and MUST be marked critical.
caKeyUsagePresentAndCriticalApplies(Cert) :-
	certs:isCA(Cert, true).

caKeyUsagePresent(Cert) :-
	certs:keyUsageExt(Cert, true).

%caKeyUsageCritical(Cert) :-
%	\+caKeyUsagePresentAndCriticalApplies(Cert).

caKeyUsageCritical(Cert) :-
	certs:keyUsageExt(Cert, true),
	certs:keyUsageCritical(Cert, true).


%  Subordinate CA Certificate: certificatePolicies 
%  MUST be present and SHOULD NOT be marked critical.
subCaCertPoliciesExtPresent(Cert) :-
	isSubCA(Cert),
	certs:certificatePoliciesExt(Cert, true).

%subCaCertPoliciesExtPresent(Cert) :-
%	\+isSubCA(Cert).

subCaCertPoliciesNotMarkedCritical(Cert) :-
	subCaCertPoliciesExtPresent(Cert),
	certs:certificatePoliciesCritical(Cert, false).	

subCaCertPoliciesNotMarkedCritical(Cert) :-
	\+isSubCA(Cert).


%  Root CA Certificate: basicConstraints MUST appear as a critical extension
rootBasicConstraintsCritical(Cert) :-
	certs:basicConstraintsExt(Cert, true),
	certs:basicConstraintsCritical(Cert, true).

rootBasicConstraintsCritical(Cert) :-
	\+isRoot(Cert).


%  Root CA Certificate: The pathLenConstraintField SHOULD NOT be present.
% Checks root CA for no length constraint
rootPathLenNotPresent(Cert) :-
	certs:pathLimit(Cert, none).

rootPathLenNotPresent(Cert) :-
	\+isRoot(Cert).


%  Root CA Certificate: extendedKeyUsage MUST NOT be present.
rootExtKeyUseNotPresent(Cert) :-
	certs:extendedKeyUsageExt(Cert, false).

rootExtKeyUseNotPresent(Cert) :-
	\+isRoot(Cert).


%  Root CA Certificate: certificatePolicies SHOULD NOT be present.
rootCertPoliciesNotPresent(Cert) :-
	certs:certificatePoliciesExt(Cert, false).

rootCertPoliciesNotPresent(Cert) :-
	\+isRoot(Cert).


%  Subscriber Certificate: extKeyUsage either the value id-kp-serverAuth
%  or id-kp-clientAuth or both values MUST be present.
%  Subscriber Certificate: extKeyUsage id-kp-emailProtection MAY be present.
%  Other values SHOULD NOT be present.
%  Subscriber Certificate: extKeyUsage: Any other values SHOULD NOT be present.

% ExtendedKeyUsage extensions allowed
allowed_EKU(serverAuth).
allowed_EKU(clientAuth).
allowed_EKU(emailProtection).

% helper function: checks for not allowed EKU
subCertEkuValuesNotAllowed(Cert) :-
	certs:extendedKeyUsage(Cert, Value),
	\+allowed_EKU(Value).

% subscriber cert: Extended key usage values allowed
subCertEkuValidFields(Cert) :-
	certs:extendedKeyUsage(Cert, serverAuth),
	\+subCertEkuValuesNotAllowed(Cert).

subCertEkuValidFields(Cert) :-
	certs:extendedKeyUsage(Cert, clientAuth),
	\+subCertEkuValuesNotAllowed(Cert).

subCertEkuValidFields(Cert) :-
	\+isSubCert(Cert).

%  To be considered Technically Constrained, the
%  Subordinate CA: Must include an EKU extension.
subCaEkuPresent(Cert) :-
	isSubCA(Cert),
	certs:extendedKeyUsageExt(Cert, true).

%subCaEkuPresent(Cert) :-
%	\+isSubCA(Cert).


%  Subordinate CA Certificate: extkeyUsage, either id-kp-serverAuth
%  or id-kp-clientAuth or both values MUST be present.
subCaEkuValidFields(Cert) :-
	subCaEkuPresent(Cert),
	certs:extendedKeyUsage(Cert, serverAuth).

subCaEkuValidFields(Cert) :-
	subCaEkuPresent(Cert),
	certs:extendedKeyUsage(Cert, clientAuth).

%subCaEkuValidFields(Cert) :-
%	\+isSubCA(Cert).


%  Subscriber Certificate: certificatePolicies MUST be present
%  and SHOULD NOT be marked critical.
subCertCertPoliciesExtPresent(Cert) :-
	isSubCert(Cert),
	certs:certificatePoliciesExt(Cert, true).

%subCertCertPoliciesExtPresent(Cert) :-
%	\+isSubCert(Cert).

subCertCertPoliciesNotMarkedCritical(Cert) :-
	certs:certificatePoliciesCritical(Cert, false).

subCertCertPoliciesNotMarkedCritical(Cert) :-
	\+isSubCert(Cert).


%  Subordinate CA Certificate: NameConstraints if present,
%  SHOULD be marked critical.

% if subCA has name constraints it must be marked critical
subCaNameConstCritApplies(Cert) :-
	isSubCA(Cert),
	certs:nameConstraintsExt(Cert, true).

subCaNameConstrainsCritical(Cert) :-
	certs:nameConstraintsCritical(Cert, true).

subCaNameConstrainsCritical(Cert) :-
	\+subCaNameConstCritApplies(Cert).


%  Root CA: SHOULD NOT contain the certificatePolicies extension.
rootCertPoliciesExtNotPresent(Cert) :-
	certs:certificatePoliciesExt(Cert, false).

rootCertPoliciesExtNotPresent(Cert) :-
	\+isRoot(Cert).


%  Subscriber Certificate: commonName is deprecated.
%  common name is deprecated if anything other than ""

% sub cert: common name is deprecated if anything other than ""
% Look at later
subCertCommonNameNotIncluded(Cert) :-
	certs:commonName(Cert, "").

subCertCommonNameNotIncluded(Cert) :-
	\+isSubCert(Cert).


%  Subscriber Certificate: commonName If present,
%  the field MUST contain a single IP address or FQDN that 
%  is one of the values contained in the subjAltName extension.
subCertCommonNameFromSanApplies(Cert) :-
	isSubCert(Cert),
	\+certs:commonName(Cert, "").

subCertCommonNameFromSan(Cert) :-
	certs:sanExt(Cert, true),
	certs:commonName(Cert, CN),
	certs:san(Cert, SN),
	string_lower(CN, CNL),
	string_lower(SN, SNL),
	equal(CNL, SNL).

%subCertCommonNameFromSan(Cert) :-
%	\+subCertCommonNameFromSanApplies(Cert).


%  Subordinate CA Certificate: cRLDistributionPoints MUST be present 
%  and MUST NOT be marked critical.
% NEED TO CHANGE crlDistributionPoints to crlDistributionPointsExt LATER WHEN CARGO BUILD WORKS
subCaCrlDistributionPointsPresent(Cert) :-
	isSubCA(Cert),
	certs:crlDistributionPointsExt(Cert, true),
	\+certs:crlDistributionPoint(Cert, false).

%subCaCrlDistributionPointsPresent(Cert) :-
%	\+isSubCA(Cert).

subCaCrlDistPointsNotMarkedCritical(Cert) :-
	subCaCrlDistributionPointsPresent(Cert),
	certs:crlDistributionPointsCritical(Cert, false).

subCaCrlDistPointsNotMarkedCritical(Cert) :-
	\+isSubCA(Cert).


%  Subordinate CA Certificate: cRLDistributionPoints MUST contain
%  the HTTP URL of the CAs CRL service.
subCaCrlDistPointContainsHttpUrl(Cert) :-
	subCaCrlDistributionPointsPresent(Cert),
	certs:crlDistributionPoint(Cert, Url),
	s_startswith(Url, "http://").

% another scenario for if there are ldap points before the http
subCaCrlDistPointContainsHttpUrl(Cert) :-
	subCaCrlDistributionPointsPresent(Cert),
	certs:crlDistributionPoint(Cert, Url),
	substring("http://", Url).

subCaCrlDistPointContainsHttpUrl(Cert) :-
	\+isSubCA(Cert).

%  Subscriber Certifcate: cRLDistributionPoints MAY be present.
%  not considered in valid scope
% NEED TO CHANGE crlDistributionPoints to crlDistributionPointsExt LATER WHEN CARGO BUILD WORKS
subCertCrlDistributionPointsPresent(Cert) :-
	isSubCert(Cert),
	certs:crlDistributionPointsExt(Cert, true),
	\+certs:crlDistributionPoint(Cert, false).

%subCertCrlDistributionPointsPresent(Cert) :-
%	\+isSubCert(Cert).

%  Subscriber Certifcate: cRLDistributionPoints MUST NOT be marked critical,
%  and MUST contain the HTTP URL of the CAs CRL service.
subCertCrlDistPointsNotMarkedCritical(Cert) :-
	certs:crlDistributionPointsCritical(Cert, false).

subCertCrlDistPointsNotMarkedCritical(Cert) :-
	certs:crlDistributionPoint(Cert, false).

subCertCrlDistPointsNotMarkedCritical(Cert) :-
	\+isSubCert(Cert).

% sub cert: cRLDistributionPoints MUST contain the HTTP URL of the CAs CRL service
subCertCrlDistPointContainsHttpUrl(Cert) :-
	certs:crlDistributionPoint(Cert, Url),
	s_startswith(Url, "http://").

subCertCrlDistPointContainsHttpUrl(Cert) :-
	certs:crlDistributionPoint(Cert, Url),
	s_occurrences(Url, "http://", N),
	equal(N, 1).

subCertCrlDistPointContainsHttpUrl(Cert) :-
	certs:crlDistributionPoint(Cert, false).

subCertCrlDistPointContainsHttpUrl(Cert) :-
	\+isSubCert(Cert).

%  Subscriber Certificate: authorityInformationAccess MUST NOT be marked critical
% helper function
subCertAIAPresent(Cert) :-
	isSubCert(Cert),
	certs:authorityInfoAccessExt(Cert, true).

subCertAIANotMarkedCritical(Cert) :-
	certs:authorityInfoAccessCritical(Cert, false).

subCertAIANotMarkedCritical(Cert) :-
	\+isSubCert(Cert).


%  Subscriber Certificate: authorityInformationAccess MUST contain the
%  HTTP URL of the Issuing CAs OSCP responder.
subCertAIAContainsOCSPUrl(Cert) :-
	certs:authorityInfoAccessLocation(Cert, "OCSP", Url),
	s_startswith(Url, "http://").

subCertAIAContainsOCSPUrl(Cert) :-
	\+isSubCert(Cert).


%  Subordinate CA Certificate: authorityInformationAccess MUST contain
%  the HTTP URL of the Issuing CAs OSCP responder.
subCAAIAPresent(Cert) :-
	isSubCA(Cert),
	certs:authorityInfoAccessExt(Cert, true).

subCAAIAContainsOCSPUrl(Cert) :-
	certs:authorityInfoAccessExt(Cert, true),
	certs:authorityInfoAccessLocation(Cert, "OCSP", Url),
	s_startswith(Url, "http://").

subCAAIAContainsOCSPUrl(Cert) :-
	\+isSubCA(Cert).


%  Subordinate CA Certificate: authorityInformationAccess SHOULD
%  also contain the HTTP URL of the Issuing CAs certificate.
subCAAIAContainsIssuingCAUrl(Cert) :-
	certs:authorityInfoAccessExt(Cert, true),
	certs:authorityInfoAccessLocation(Cert, "CA Issuers", Url),
	s_startswith(Url, "http://").

subCAAIAContainsIssuingCAUrl(Cert) :-
	\+isSubCA(Cert).


%  the CA MUST establish and follow a documented procedure[^pubsuffix] that
%  determines if the wildcard character occurs in the first label position to
%  the left of a “registry‐controlled” label or “public suffix”
dnsWildcardNotLeftOfPublicSuffixApplies(Cert) :-
	isSubCert(Cert),
	certs:sanExt(Cert, true).

dnsWildcardNotLeftOfPublicSuffixApplies(Cert) :-
	isSubCert(Cert),
	\+certs:commonName(Cert, "").

dnsWildcardLeftOfPublicSuffix(San) :-
	string_concat("*.", X, San),
	public_suffix(X).

dnsWildcardLeftOfPublicSuffix(San) :-
	public_suffix(Pubsuff),
	string_concat("*.", Pubsuff, NotAllowed),
	s_endswith(San, NotAllowed).

dnsWildcardNotLeftOfPublicSuffix(Cert) :-
	certs:sanExt(Cert, true),
	certs:san(Cert, San),
	\+dnsWildcardLeftOfPublicSuffix(San).

dnsWildcardNotLeftOfPublicSuffix(Cert) :-
	certs:commonName(Cert, CommonName),
	\+dnsWildcardLeftOfPublicSuffix(CommonName).

dnsWildcardNotLeftOfPublicSuffix(Cert) :-
 	\+isSubCert(Cert).

% Rules are tested here
verified(Cert) :-
	std:isCert(Cert),
	dnsWildcardNotLeftOfPublicSuffix(Cert).

% Trusted roots needed for testing
%trusted_roots("4F39D3BB9E7FA7BFB290E9D21EBB7827D3D7F89394A3AE0F46F50D7583FFBC84").
%trusted_roots("BEC94911C2955676DB6C0A550986D76E3BA005667C442C9762B4FBB773DE228C").
%trusted_roots("001BD98347D99058CD3D1CCE175922BF032FA33A5456B7B1625B5914D0C429FB").
%trusted_roots("4CC434E240BBDF1900D4AD568B5EA48A1721CEE0397C7AE582CF6F2FFF11C711").
%trusted_roots("BEC94911C2955676DB6C0A550986D76E3BA005667C442C9762B4FBB773DE228C").



% Converts lua rules into prolog rules
equal(X, Y):-
    X == Y.

larger(X, Y):-
    X > Y.

geq(X, Y):-
    X >= Y.

add(X, Y, Z):-
    X is Y + Z.

subtract(X, Y, Z):-
    X is Y - Z.

modulus(X, Y, Z) :- 
  X is Y mod Z.

s_endswith(String, Suffix):-
    string_concat(_, Suffix, String).

s_startswith(String, Prefix):-
    string_concat(Prefix, _, String).

substring(X,S) :-
  append(_,T,S) ,
  append(X,_,T) ,
  X \= [].

s_occurrences(Str, Chr, Num) :-
    string_chars(Str, Lst),
    count(Lst, Chr, Num).

count([],_,0).
count([X|T],X,Y):- count(T,X,Z), Y is 1+Z.
count([_|T],X,Z):- count(T,X,Z).

trusted_roots("02ED0EB28C14DA45165C566791700D6451D7FB56F0B2AB1D3B8EB070E56EDFF5").
trusted_roots("0376AB1D54C5F9803CE4B2E201A0EE7EEF7B57B636E8A93C9B8D4860C96F5FA7").
trusted_roots("04048028BF1F2864D48F9AD4D83294366A828856553F3B14303F90147F5D40EF").
trusted_roots("063E4AFAC491DFD332F3089B8542E94617D893D7FE944E10A7937EE29D9693C0").
trusted_roots("0687260331A72403D909F105E69BCF0D32E1BD2493FFC6D9206D11BCD6770739").
trusted_roots("0753E940378C1BD5E3836E395DAEA5CB839E5046F1BD0EAE1951CF10FEC7C965").
trusted_roots("0A81EC5A929777F145904AF38D5D509F66B5E2C58FCDB531058B0E17F3F0B41B").
trusted_roots("0C2CD63DF7806FA399EDE809116B575BF87989F06518F9808C860503178BAF66").
trusted_roots("125609AA301DA0A249B97A8239CB6A34216F44DCAC9F3954B14292F2E8C8608F").
trusted_roots("136335439334A7698016A0D324DE72284E079D7B5220BB8FBD747816EEBEBACA").
trusted_roots("1465FA205397B876FAA6F0A9958E5590E40FCC7FAA4FB7C2C8677521FB5FB658").
trusted_roots("15D5B8774619EA7D54CE1CA6D0B0C403E037A917F131E8A04E1E6B7A71BABCE5").
trusted_roots("15F0BA00A3AC7AF3AC884C072B1011A077BD77C097F40164B2F8598ABD83860C").
trusted_roots("16AF57A9F676B0AB126095AA5EBADEF22AB31119D644AC95CD4B93DBF3F26AEB").
trusted_roots("1793927A0614549789ADCE2F8F34F7F0B66D0F3AE3A3B84D21EC15DBBA4FADC7").
trusted_roots("179FBC148A3DD00FD24EA13458CC43BFA7F59C8182D783A513F6EBEC100C8924").
trusted_roots("18CE6CFE7BF14E60B2E347B8DFE868CB31D02EBB3ADA271569F50343B46DB3A4").
trusted_roots("18F1FC7F205DF8ADDDEB7FE007DD57E3AF375A9C4D8D73546BF4F1FED1E18D35").
trusted_roots("1BA5B2AA8C65401A82960118F80BEC4F62304D83CEC4713A19C39C011EA46DB4").
trusted_roots("22A2C1F7BDED704CC1E701B5F408C310880FE956B5DE2A4A44F99C873A25A7C8").
trusted_roots("2399561127A57125DE8CEFEA610DDF2FA078B5C8067F4E828290BFB860E84B3C").
trusted_roots("2530CC8E98321502BAD96F9B1FBA1B099E2D299E0F4548BB914F363BC0D4531F").
trusted_roots("2A575471E31340BC21581CBD2CF13E158463203ECE94BCF9D3CC196BF09A5472").
trusted_roots("2CABEAFE37D06CA22ABA7391C0033D25982952C453647349763A3AB5AD6CCF69").
trusted_roots("2CE1CB0BF9D2F9E102993FBE215152C3B2DD0CABDE1C68E5319B839154DBB7F5").
trusted_roots("2E7BF16CC22485A7BBE2AA8696750761B0AE39BE3B2FE9D0CC6D4EF73491425C").
trusted_roots("30D0895A9A448A262091635522D1F52010B5867ACAE12C78EF958FD4F4389F2F").
trusted_roots("31AD6648F8104138C738F39EA4320133393E3A18CC02296EF97C2AC9EF6731D0").
trusted_roots("3417BB06CC6007DA1B961C920B8AB4CE3FAD820E4AA30B9ACBC4A74EBDCEBC65").
trusted_roots("37D51006C512EAAB626421F1EC8C92013FC5F82AE98EE533EB4619B8DEB4D06C").
trusted_roots("3C4FB0B95AB8B30032F432B86F535FE172C185D0FD39865837CF36187FA6F428").
trusted_roots("3C5F81FEA5FAB82C64BFA2EAECAFCDE8E077FC8620A7CAE537163DF36EDBF378").
trusted_roots("3E84BA4342908516E77573C0992F0979CA084E4685681FF195CCBA8A229B8A76").
trusted_roots("3E9099B5015E8F486C00BCEA9D111EE721FABA355A89BCF1DF69561E3DC6325C").
trusted_roots("40F6AF0346A99AA1CD1D555A4E9CCE62C7F9634603EE406615833DC8C8D00367").
trusted_roots("41C923866AB4CAD6B7AD578081582E020797A6CBDF4FFF78CE8396B38937D7F5").
trusted_roots("4200F5043AC8590EBB527D209ED1503029FBCBD41CA1B506EC27F15ADE7DAC69").
trusted_roots("4348A0E9444C78CB265E058D5E8944B4D84F9662BD26DB257F8934A443C70161").
trusted_roots("43DF5774B03E7FEF5FE40D931A7BEDF1BB2E6B42738C4E6D3841103D3AA7F339").
trusted_roots("44B545AA8A25E65A73CA15DC27FC36D24C1CB9953A066539B11582DC487B4833").
trusted_roots("45140B3247EB9CC8C5B4F0D7B53091F73292089E6E5A63E2749DD3ACA9198EDA").
trusted_roots("46EDC3689046D53A453FB3104AB80DCAEC658B2660EA1629DD7E867990648716").
trusted_roots("49E7A442ACF0EA6287050054B52564B650E4F49E42E348D6AA38E039E957B1C1").
trusted_roots("4B03F45807AD70F21BFC2CAE71C9FDE4604C064CF5FFB686BAE5DBAAD7FDD34C").
trusted_roots("4D2491414CFE956746EC4CEFA6CF6F72E28A1329432F9D8A907AC4CB5DADC15A").
trusted_roots("4FF460D54B9C86DABFBCFC5712E0400D2BED3FBC4D4FBDAA86E06ADCD2A9AD7A").
trusted_roots("513B2CECB810D4CDE5DD85391ADFC6C2DD60D87BB736D2B521484AA47A0EBEF6").
trusted_roots("52F0E1C4E58EC629291B60317F074671B85D7EA80D5B07273463534B32B40234").
trusted_roots("54455F7129C20B1447C418F997168F24C58FC5023BF5DA5BE2EB6E1DD8902ED5").
trusted_roots("552F7BDCF1A7AF9E6CE672017F4F12ABF77240C78E761AC203D1D9D20AC89988").
trusted_roots("55926084EC963A64B96E2ABE01CE0BA86A64FBFEBCC7AAB5AFC155B37FD76066").
trusted_roots("568D6905A2C88708A4B3025190EDCFEDB1974A606A13C6E5290FCB2AE63EDAB5").
trusted_roots("59769007F7685D0FCD50872F9F95D5755A5B2B457D81F3692B610A98672F0E1B").
trusted_roots("5A2FC03F0C83B090BBFA40604B0988446C7636183DF9846E17101A447FB8EFD6").
trusted_roots("5A885DB19C01D912C5759388938CAFBBDF031AB2D48E91EE15589B42971D039C").
trusted_roots("5C58468D55F58E497E743982D2B50010B6D165374ACF83A7D4A32DB768C4408E").
trusted_roots("5CC3D78E4E1D5E45547A04E6873E64F90CF9536D1CCC2EF800F355C4C5FD70FD").
trusted_roots("5D56499BE4D2E08BCFCAD08A3E38723D50503BDE706948E42F55603019E528AE").
trusted_roots("5EDB7AC43B82A06A8761E8D7BE4979EBF2611F7DD79BF91C1C6B566A219ED766").
trusted_roots("62DD0BE9B9F50A163EA0F8E75C053B1ECA57EA55C8688F647C6881F2C8357B95").
trusted_roots("668C83947DA63B724BECE1743C31A0E6AED0DB8EC5B31BE377BB784F91B6716F").
trusted_roots("687FA451382278FFF0C8B11F8D43D576671C6EB2BCEAB413FB83D965D06D2FF2").
trusted_roots("69DDD7EA90BB57C93E135DC85EA6FCD5480B603239BDC454FC758B2A26CF7F79").
trusted_roots("6B9C08E86EB0F767CFAD65CD98B62149E5494A67F5845E7BD1ED019F27B86BD6").
trusted_roots("6C61DAC3A2DEF031506BE036D2A6FE401994FBD13DF9C8D466599274C446EC98").
trusted_roots("6DC47172E01CBCB0BF62580D895FE2B8AC9AD4F873801E0C10B9C837D21EB177").
trusted_roots("70A73F7F376B60074248904534B11482D5BF0E698ECC498DF52577EBF2E93B9A").
trusted_roots("71CCA5391F9E794B04802530B363E121DA8A3043BB26662FEA4DCA7FC951A4BD").
trusted_roots("73C176434F1BC6D5ADF45B0E76E727287C8DE57616C1E6E6141A2B2CBC7D8E4C").
trusted_roots("7431E5F4C3C1CE4690774F0B61E05440883BA9A01ED00BA6ABD7806ED3B118CF").
trusted_roots("7600295EEFE85B9E1FD624DB76062AAAAE59818A54D2774CD4C0B2C01131E1B3").
trusted_roots("7908B40314C138100B518D0735807FFBFCF8518A0095337105BA386B153DD927").
trusted_roots("7D05EBB682339F8C9451EE094EEBFEFA7953A114EDB2F44949452FAB7D2FC185").
trusted_roots("7E37CB8B4C47090CAB36551BA6F45DB840680FBA166A952DB100717F43053FC2").
trusted_roots("8560F91C3624DABA9570B5FEA0DBE36FF11A8323BE9486854FB3F34A5571198D").
trusted_roots("85666A562EE0BE5CE925C1D8890A6F76A87EC16D4D7D5F29EA7419CF20123B69").
trusted_roots("85A0DD7DD720ADB7FF05F83D542B209DC7FF4528F7D677B18389FEA5E5C49E86").
trusted_roots("86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B").
trusted_roots("88497F01602F3154246AE28C4D5AEF10F1D87EBB76626F4AE0B7F95BA7968799").
trusted_roots("88EF81DE202EB018452E43F864725CEA5FBD1FC2D9D205730709C5D8B8690F46").
trusted_roots("8A866FD1B276B57E578E921C65828A2BED58E9F2F288054134B7F1F4BFC9CC74").
trusted_roots("8D722F81A9C113C0791DF136A2966DB26C950A971DB46B4199F4EA54B78BFB9F").
trusted_roots("8ECDE6884F3D87B1125BA31AC3FCB13D7016DE7F57CC904FE1CB97C6AE98196E").
trusted_roots("8FE4FB0AF93A4D0D67DB0BEBB23E37C71BF325DCBCDD240EA04DAF58B47E1840").
trusted_roots("91E2F5788D5810EBA7BA58737DE1548A8ECACD014598BC0B143E041B17052552").
trusted_roots("960ADF0063E96356750C2965DD0A0867DA0B9CBD6E77714AEAFB2349AB393DA3").
trusted_roots("96BCEC06264976F37460779ACF28C5A7CFE8A3C0AAE11A8FFCEE05C0BDDF08C6").
trusted_roots("9A114025197C5BB95D94E63D55CD43790847B646B23CDF11ADA4A00EFF15FB48").
trusted_roots("9A6EC012E1A7DA9DBE34194D478AD7C0DB1822FB071DF12981496ED104384113").
trusted_roots("9ACFAB7E43C8D880D06B262A94DEEEE4B4659989C3D0CAF19BAF6405E41AB7DF").
trusted_roots("9BEA11C976FE014764C1BE56A6F914B5A560317ABD9988393382E5161AA0493C").
trusted_roots("A0234F3BC8527CA5628EEC81AD5D69895DA5680DC91D1CB8477F33F878B95B0B").
trusted_roots("A040929A02CE53B4ACF4F2FFC6981CE4496F755E6D45FE0B2A692BCD52523F36").
trusted_roots("A0459B9F63B22559F5FA5D4C6DB3F9F72FF19342033578F073BF1D1B46CBB912").
trusted_roots("A1339D33281A0B56E557D3D32B1CE7F9367EB094BD5FA72A7E5004C8DED7CAFE").
trusted_roots("A4310D50AF18A6447190372A86AFAF8B951FFB431D837F1E5688B45971ED1557").
trusted_roots("A45EDE3BBBF09C8AE15C72EFC07268D693A21C996FD51E67CA079460FD6D8873").
trusted_roots("B0BFD52BB0D7D9BD92BF5D4DC13DA255C02C542F378365EA893911F55E55F23C").
trusted_roots("B478B812250DF878635C2AA7EC7D155EAA625EE82916E2CD294361886CD1FBD4").
trusted_roots("B676F2EDDAE8775CD36CB0F63CD1D4603961F49E6265BA013A2F0307B6D0B804").
trusted_roots("BC104F15A48BE709DCA542A7E1D4B9DF6F054527E802EAA92D595444258AFE71").
trusted_roots("BC4D809B15189D78DB3E1D8CF4F9726A795DA1643CA5F1358E1DDB0EDC0D7EB3").
trusted_roots("BD71FDF6DA97E4CF62D1647ADD2581B07D79ADF8397EB4ECBA9C5E8488821423").
trusted_roots("BE6C4DA2BBB9BA59B6F3939768374246C3C005993FA98F020D1DEDBED48A81D5").
trusted_roots("BEC94911C2955676DB6C0A550986D76E3BA005667C442C9762B4FBB773DE228C").
trusted_roots("BF0FEEFB9E3A581AD5F9E9DB7589985743D261085C4D314F6F5D7259AA421612").
trusted_roots("BFD88FE1101C41AE3E801BF8BE56350EE9BAD1A6B9BD515EDC5C6D5B8711AC44").
trusted_roots("BFFF8FD04433487D6A8AA60C1A29767A9FC2BBB05E420F713A13B992891D3893").
trusted_roots("C0A6F4DC63A24BFDCF54EF2A6A082A0A72DE35803E2FF5FF527AE5D87206DFD5").
trusted_roots("C1B48299ABA5208FE9630ACE55CA68A03EDA5A519C8802A0D3A673BE8F8E557D").
trusted_roots("C3846BF24B9E93CA64274C0EC67C1ECC5E024FFCACD2D74019350E81FE546AE4").
trusted_roots("C45D7BB08E6D67E62E4235110B564E5F78FD92EF058C840AEA4E6455D7585C60").
trusted_roots("CA42DD41745FD0B81EB902362CF9D8BF719DA1BD1B1EFC946F5B4C99F42C1B9E").
trusted_roots("CB3CCBB76031E5E0138F8DD39A23F9DE47FFC35E43C1144CEA27D46A5AB1CB5F").
trusted_roots("CBB522D7B7F127AD6A0113865BDF1CD4102E7D0759AF635A7CF4720DC963C53B").
trusted_roots("CECDDC905099D8DADFC5B1D209B737CBE2C18CFB2C10C0FF0BCF0D3286FC1AA2").
trusted_roots("D40E9C86CD8FE468C1776959F49EA774FA548684B6C406F3909261F4DCE2575C").
trusted_roots("D43AF9B35473755C9684FC06D7D8CB70EE5C28E773FB294EB41EE71722924D24").
trusted_roots("D48D3D23EEDB50A459E55197601C27774B9D7B18C94D5A059511A10250B93168").
trusted_roots("D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4").
trusted_roots("DB3517D1F6732A2D5AB97C533EC70779EE3270A62FB4AC4238372460E6F01E88").
trusted_roots("DD6936FE21F8F077C123A1A521C12224F72255B73E03A7260693E8A24B0FA389").
trusted_roots("E23D4A036D7B70E9F595B1422079D2B91EDFBB1FB651A0633EAA8A9DC5F80703").
trusted_roots("E35D28419ED02025CFA69038CD623962458DA5C695FBDEA3C22B0BFB25897092").
trusted_roots("E3B6A2DB2ED7CE48842F7AC53241C7B71D54144BFB40C11F3F1D0B42F5EEA12D").
trusted_roots("E75E72ED9F560EEC6EB4800073A43FC3AD19195A392282017895974A99026B6C").
trusted_roots("E793C9B02FD8AA13E21C31228ACCB08119643B749C898964B1746D46C3D4CBD2").
trusted_roots("EAA962C4FA4A6BAFEBE415196D351CCD888D4F53F3FA8AE6D7C466A94E6042BB").
trusted_roots("EB04CF5EB1F39AFA762F2BB120F296CBA520C1B97DB1589565B81CB9A17B7244").
trusted_roots("EBC5570C29018C4D67B1AA127BAF12F703B4611EBC17B7DAB5573894179B93FA").
trusted_roots("EBD41040E4BB3EC742C9E381D31EF2A41A48B6685C96E7CEF3C1DF6CD4331C99").
trusted_roots("EDF7EBBCA27A2A384D387B7D4010C666E2EDB4843E4C29B4AE1D5B9332E6B24D").
trusted_roots("EEC5496B988CE98625B934092EEC2908BED0B0F316C2D4730C84EAF1F3D34881").
trusted_roots("F1C1B50AE5A20DD8030EC9F6BC24823DD367B5255759B4E71B61FCE9F7375D73").
trusted_roots("F356BEA244B7A91EB35D53CA9AD7864ACE018E2D35D5F8F96DDF68A6F41AA474").
trusted_roots("F9E67D336C51002AC054C632022D66DDA2E7E3FFF10AD061ED31D8BBB410CFB2").
trusted_roots("FD73DAD31C644FF1B43BEF0CCDDA96710B9CD9875ECA7E31707AF3E96D522BBD").
trusted_roots("FF856A2D251DCD88D36656F450126798CFABAADE40799C722DE4D2B5DB36A73A").
trusted_roots("52E36BE5D0E39B7A06DC26A9A5A5B6F7DA3F313BF62BD19D967615BFD58C81CC").
trusted_roots("4CC434E240BBDF1900D4AD568B5EA48A1721CEE0397C7AE582CF6F2FFF11C711").