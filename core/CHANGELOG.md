# CHANGELOG

## 1/29/19
* Removing all Ergatis modules that are CGI related, so that Docker services can be split better

## 10/17/16
* Modifying substitute_in_wrapper.sh to work outside of Docker by accepting args
* TODO - Modify substitute_in_wrapper.sh to handle both Perl and Python script cases, depending on the extension
* TODO - Change ergatis.ini in htdocs to be more centered with internal Ergatis version