#!/bin/bash
# LICENSE CDDL 1.0 + GPL 2.0
#
# Copyright (c) 1982-2016 Oracle and/or its affiliates. All rights reserved.
# 
# Since: November, 2016
# Author: gerald.venzl@oracle.com
# Description: Runs the Oracle Database inside the container
# 
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
# 


if [ "$SVN_USER" == "" ]; then
   echo "Error: The SVN_USER must be provided"
   exit 1;
fi;

if [ "$SVN_PASSWORD" == "" ]; then
   echo "Error: The SVN_PASSWORD must be provided"
   exit 1;
fi;

echo "Checkout wiht User: $SVN_USER PW: $SVN_PASSWORD"

export LC_CTYPE=en_US.UTF-8

svn checkout HTTP://172.16.46.6/svn/project/product/updatescript/trunk updatescript --non-interactive --no-auth-cache --username $SVN_USER --password $SVN_PASSWORD
if [ $? == 0 ]; then
   echo "Checkout Updatescript trunk successful completed"

else
   echo "Failed to checkout Updatescript!!!!!"
   exit 1;
fi;

cp -Rvf updatescript/update-tools .

svn checkout HTTP://172.16.46.6/svn/project/product/api/trunk api --non-interactive --no-auth-cache --username $SVN_USER --password $SVN_PASSWORD
if [ $? == 0 ]; then
   echo "Checkout API trunk successful completed"

else
   echo "Failed to checkout API!!!!!"
   exit 1;
fi;

svn checkout HTTP://172.16.46.6/svn/project/product/module/PlsqlAutoTest/trunk plsqlautotest --non-interactive --no-auth-cache --username $SVN_USER --password $SVN_PASSWORD
if [ $? == 0 ]; then
   echo "Checkout PlsqlAutoTest trunk successful completed"

else
   echo "Failed to checkout PlsqlAutoTest!!!!!"
   exit 1;
fi;

echo "current directory ${PWD}"

cd plsqlautotest
chmod +x gradlew

cat > gradle.properties << EOL 
systemProp.artifact.repository.web.uri=http://172.16.46.4/ivy-repository
systemProp.plsqlautotest.api.db.dir=/api/api/db
systemProp.plsqlautotest.db.sys.pswd=TIE2002sys
systemProp.plsqlautotest.db.url=jdbc:Oracle:thin:@localhost:1521:XE
systemProp.plsqlautotest.db.schema.user=PLSQLAUTOTEST
systemProp.plsqlautotest.db.schema.pswd=secnt
systemProp.plsqlautotest.updateonly=false
EOL

./gradlew run
