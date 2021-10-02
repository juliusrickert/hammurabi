#!/bin/bash

# The following rudimentry code runs a series of lints using the zlint file 
# in prolog/gen/job/zlint.pl (emulates zlint)
# *Note that the file can be changed in the while loop

# The code queries each lint in prolog/static/applies_rules.txt 
# The apply rule and lint rule are seperated by a ";" with the 
# applies rule coming first 
# If a rule doesnt apply, it will just return "NA"
# I had to "invert" some of my rules in the zlint file so 
# that they are true when the certificate is correct 

# Usage: ./scripts/zlint.sh testdata/caValCountry.pem | jq
# *The jq is used to format the output

./target/debug/single chrome $1 foo.com --ocsp > /dev/null
echo -n "{"
while IFS=";", read -r apply lint; do
    result=`python3 prolog/static/driver.py prolog/static/zlint.pl $lint $apply`
    echo -n "\"$lint\": {\"result\": \"$result\"},"
done < prolog/static/applies_rules.txt
echo -n "\"end\": \"pass\"}" # Update this in future