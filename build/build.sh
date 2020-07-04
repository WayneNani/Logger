##!/cygdrive/c/cygwin/bin/bash
#!/bin/bash

#*** PARAMETERS ***
#	$1 = VERSION_NUMBER x.x.x (ex 1.0.5)
#		This will be used to generate the release folder etc
#		OLD: #read -p "New Version Number x.x.x ?" VERSION_NUMBER

VERSION_NUMBER=$1
SQL_CONNECTION=$2
INCLUDE_RELEASE_FOLDER=$3

{
if [ -z "${VERSION_NUMBER}" ]; then
  echo "VERSION_NUMBER (parameter 1) is not defined"
  exit 0
fi
if [ -z "${SQL_CONNECTION}" ]; then
	echo "SQL_CONNECTION (parameter 2) is not defined"
	exit 0
fi

#91: Allow option to include release folder or not. Useful for developers, but should be excluded by default
#Upper value
INCLUDE_RELEASE_FOLDER=$(echo $INCLUDE_RELEASE_FOLDER | awk '{print toupper($0)}')
if [ "$INCLUDE_RELEASE_FOLDER" = "" ]; then
	INCLUDE_RELEASE_FOLDER=N
fi
echo "INCLUDE_RELEASE_FOLDER: $INCLUDE_RELEASE_FOLDER"
}

echo "Building release $VERSION_NUMBER"


#*** VARIABLES ***
RELEASE_FOLDER=../releases/$VERSION_NUMBER
INSTALL=$RELEASE_FOLDER/"logger_install.sql"


#Clear release folder (if it exists) and make directory
rm -rf ../releases/$VERSION_NUMBER
mkdir ../releases/$VERSION_NUMBER


#Build files

#rm -f ../build/logger_install.sql
#rm -f ../build/logger_latest.zip
#rm -f ../build/logger_no_op.sql

#PREINSTALL
cat ../source/install/logger_install_prereqs.sql > $INSTALL
printf '\n' >> $INSTALL


#TABLES
printf 'PROMPT tables/logger_logs.sql \n' | tee -a $INSTALL > /dev/null
cat ../source/tables/logger_logs.sql | tee -a $INSTALL > /dev/null
printf '\n' | tee -a $INSTALL > /dev/null
printf 'PROMPT tables/logger_prefs.sql \n' | tee -a $INSTALL > /dev/null
cat ../source/tables/logger_prefs.sql | tee -a $INSTALL > /dev/null
printf '\n' | tee -a $INSTALL > /dev/null
printf 'PROMPT tables/logger_logs_apex_items.sql \n' | tee -a $INSTALL > /dev/null
cat ../source/tables/logger_logs_apex_items.sql | tee -a $INSTALL > /dev/null
printf '\n' | tee -a $INSTALL > /dev/null
printf 'PROMPT tables/logger_prefs_by_client_id.sql \n' | tee -a $INSTALL > /dev/null
cat ../source/tables/logger_prefs_by_client_id.sql | tee -a $INSTALL > /dev/null
printf '\n' | tee -a $INSTALL > /dev/null

#JOBS
printf 'PROMPT jobs/logger_purge_job.sql \n' >> $INSTALL
cat ../source/jobs/logger_purge_job.sql >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT jobs/logger_unset_prefs_by_client.sql \n' >> $INSTALL
cat ../source/jobs/logger_unset_prefs_by_client.sql >> $INSTALL
printf '\n' >> $INSTALL

#VIEWS
printf 'PROMPT views/logger_logs_5_min.sql \n' | tee -a $INSTALL > /dev/null
cat ../source/views/logger_logs_5_min.sql | tee -a $INSTALL > /dev/null
printf '\n' | tee -a $INSTALL > /dev/null
printf 'PROMPT views/logger_logs_60_min.sql \n' | tee -a $INSTALL > /dev/null
cat ../source/views/logger_logs_60_min.sql | tee -a $INSTALL > /dev/null
printf '\n' | tee -a $INSTALL > /dev/null
printf 'PROMPT views/logger_logs_terse.sql\n' | tee -a $INSTALL > /dev/null
cat ../source/views/logger_logs_terse.sql | tee -a $INSTALL > /dev/null
printf '\n' | tee -a $INSTALL > /dev/null

#PACKAGES
printf 'PROMPT packages/logger.pks \n' >> $INSTALL
cat ../source/packages/logger.pks >> $INSTALL
printf '\n' >> $INSTALL
printf 'PROMPT packages/logger.pkb \n' >> $INSTALL
cat ../source/packages/logger.pkb >> $INSTALL
printf '\n' >> $INSTALL


#Recompile logger_prefs trigger as it has dependencies on logger.pks
printf 'PROMPT Recompile biu_logger_prefs after logger.pkb \n' >> $INSTALL
printf '\nalter trigger biu_logger_prefs compile;\n' | tee -a $INSTALL > /dev/null

#CONTEXTS
printf 'PROMPT contexts/logger_context.sql \n' >> $INSTALL
cat ../source/contexts/logger_context.sql >> $INSTALL
printf '\n' >> $INSTALL

#PROCEDURES
printf 'PROMPT procedures/logger_configure.plb \n' >> $INSTALL
cat ../source/procedures/logger_configure.plb >> $INSTALL
printf '\n' >> $INSTALL


#Post install
printf 'PROMPT install/post_install_configuration.sql \n' >> $INSTALL
cat ../source/install/post_install_configuration.sql >> $INSTALL
printf '\n' >> $INSTALL




#Recompile logger_logs_terse since it depends on logger
printf '\nalter view logger_logs_terse compile;\n' | tee -a $INSTALL > /dev/null

#Copy "other" scripts
cp -f ../source/install/create_user.sql $RELEASE_FOLDER
cp -f ../source/install/drop_logger.sql $RELEASE_FOLDER

#Copy Scripts
cp -r ../source/scripts $RELEASE_FOLDER

#Copy main package file for developers to easily review
cp -f ../source/packages/logger.* $RELEASE_FOLDER

#Copy README
cp -f ../README.md $RELEASE_FOLDER

#Copy demo scripts
cp -fr ../demos $RELEASE_FOLDER

#Copy docs #89
cp -fr ../docs $RELEASE_FOLDER

#Copy License
cp -f ../LICENSE $RELEASE_FOLDER


chmod 777 $RELEASE_FOLDER/*.*


#Replace any references for the version number
sed -i.del "s/x\.x\.x/$VERSION_NUMBER/g" $RELEASE_FOLDER/logger_install.sql
sed -i.del "s/x\.x\.x/$VERSION_NUMBER/g" $RELEASE_FOLDER/logger.pks
#need to remove the backup file required for sed call
rm -rf $RELEASE_FOLDER/*.del



#Old windows zip7za a -tzip $/logger_$VERSION_NUMBER.zip ../build/*.sql ../build/*.html
#By CDing into the release_folder we don't get the full path in the zip file
cd $RELEASE_FOLDER
zip -r logger_$VERSION_NUMBER.zip .

#91: Copy zip to release root
cp -f logger_$VERSION_NUMBER.zip ../.

#Remove release folder if appliable
if [ "$INCLUDE_RELEASE_FOLDER" != "Y" ]; then
  echo Removing release folder
  cd $START_DIR
  rm -rf $RELEASE_FOLDER
else
  echo Keeping release folder
fi
