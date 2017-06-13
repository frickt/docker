#!/bin/bash

########### Move DB files ############
function moveFiles {
   if [ ! -d $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID ]; then
      su -p oracle -c "mkdir -p $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/"
   fi;
   
   su -p oracle -c "mv $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/"
   su -p oracle -c "mv $ORACLE_HOME/dbs/orapw$ORACLE_SID $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/"
   su -p oracle -c "mv $ORACLE_HOME/network/admin/tnsnames.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/"
   su -p oracle -c "mv $ORACLE_HOME/network/admin/listener.ora $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/"
   mv /etc/sysconfig/oracle-xe $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/
      
   symLinkFiles;
}

########### Symbolic link DB files ############
function symLinkFiles {

   if [ ! -L $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora ]; then
      ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/spfile$ORACLE_SID.ora $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora
   fi;
   
   if [ ! -L $ORACLE_HOME/dbs/orapw$ORACLE_SID ]; then
      ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/orapw$ORACLE_SID $ORACLE_HOME/dbs/orapw$ORACLE_SID
   fi;
   
   if [ ! -L $ORACLE_HOME/network/admin/tnsnames.ora ]; then
      ln -sf $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora
   fi;
   
   if [ ! -L $ORACLE_HOME/network/admin/listener.ora ]; then
      ln -sf $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/listener.ora $ORACLE_HOME/network/admin/listener.ora
   fi;
   
   if [ ! -L /etc/sysconfig/oracle-xe ]; then
      ln -s $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/oracle-xe /etc/sysconfig/oracle-xe
   fi;
}

########### SIGTERM handler ############
function _term() {
   echo "Stopping container."
   echo "SIGTERM received, shutting down database!"
  /etc/init.d/oracle-xe stop
}

########### SIGKILL handler ############
function _kill() {
   echo "SIGKILL received, shutting down database!"
   /etc/init.d/oracle-xe stop
}

############# Create DB ################
function createDB {
   # Auto generate ORACLE PWD if not passed on
   export ORACLE_PWD=${ORACLE_PWD:-"`openssl rand -hex 8`"}
   echo "ORACLE PASSWORD FOR SYS AND SYSTEM: $ORACLE_PWD";

   sed -i -e "s|###ORACLE_PWD###|$ORACLE_PWD|g" $ORACLE_BASE/$CONFIG_RSP && \
   /etc/init.d/oracle-xe configure responseFile=$ORACLE_BASE/$CONFIG_RSP

   # Listener 
   echo "LISTENER = \
  (DESCRIPTION_LIST = \
    (DESCRIPTION = \
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC_FOR_XE)) \
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521)) \
    ) \
  ) \
\
" > $ORACLE_HOME/network/admin/listener.ora

   echo "DEDICATED_THROUGH_BROKER_LISTENER=ON"  >> $ORACLE_HOME/network/admin/listener.ora && \
   echo "DIAG_ADR_ENABLED = off"  >> $ORACLE_HOME/network/admin/listener.ora;

   su -p oracle -c "sqlplus / as sysdba <<EOF
      EXEC DBMS_XDB.SETLISTENERLOCALACCESS(FALSE);
      
      ALTER DATABASE ADD LOGFILE GROUP 4 ('$ORACLE_BASE/oradata/$ORACLE_SID/redo04.log') SIZE 50m;
      ALTER DATABASE ADD LOGFILE GROUP 5 ('$ORACLE_BASE/oradata/$ORACLE_SID/redo05.log') SIZE 50m;
      ALTER DATABASE ADD LOGFILE GROUP 6 ('$ORACLE_BASE/oradata/$ORACLE_SID/redo06.log') SIZE 50m;
      ALTER SYSTEM SWITCH LOGFILE;
      ALTER SYSTEM SWITCH LOGFILE;
      ALTER SYSTEM CHECKPOINT;
      ALTER DATABASE DROP LOGFILE GROUP 1;
      ALTER DATABASE DROP LOGFILE GROUP 2;
      ALTER SYSTEM SET disk_asynch_io = FALSE SCOPE = SPFILE; 
      ALTER SYSTEM SET db_recovery_file_dest='';

      CREATE PROFILE IENGINE_USERS LIMIT PASSWORD_LIFE_TIME UNLIMITED CPU_PER_SESSION UNLIMITED CPU_PER_CALL UNLIMITED LOGICAL_READS_PER_SESSION UNLIMITED LOGICAL_READS_PER_CALL UNLIMITED IDLE_TIME UNLIMITED;

      CREATE PROFILE PARADOCS_USERS LIMIT CPU_PER_SESSION UNLIMITED CPU_PER_CALL UNLIMITED CONNECT_TIME DEFAULT IDLE_TIME UNLIMITED SESSIONS_PER_USER DEFAULT LOGICAL_READS_PER_SESSION UNLIMITED LOGICAL_READS_PER_CALL UNLIMITED PRIVATE_SGA DEFAULT COMPOSITE_LIMIT DEFAULT FAILED_LOGIN_ATTEMPTS DEFAULT PASSWORD_LOCK_TIME DEFAULT PASSWORD_GRACE_TIME DEFAULT PASSWORD_LIFE_TIME DEFAULT PASSWORD_REUSE_MAX DEFAULT PASSWORD_REUSE_TIME DEFAULT PASSWORD_VERIFY_FUNCTION DEFAULT;
      CREATE PROFILE IEUSERS LIMIT PASSWORD_LIFE_TIME UNLIMITED CPU_PER_SESSION UNLIMITED CPU_PER_CALL UNLIMITED LOGICAL_READS_PER_SESSION UNLIMITED LOGICAL_READS_PER_CALL UNLIMITED IDLE_TIME UNLIMITED;

      CREATE SMALLFILE TABLESPACE "PDCS" DATAFILE '$ORACLE_BASE/oradata/$ORACLE_SID/pdcs.dbf' SIZE 2G REUSE AUTOEXTEND ON NEXT 10M MAXSIZE 5G LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
      CREATE SMALLFILE TABLESPACE "PDCS_BLOB_SPACE" DATAFILE '$ORACLE_BASE/oradata/$ORACLE_SID/pdcs_blob_space.dbf' SIZE 500M REUSE AUTOEXTEND ON NEXT 10M MAXSIZE 1G LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
      CREATE SMALLFILE TABLESPACE "PDCSIMAGE" DATAFILE '$ORACLE_BASE/oradata/$ORACLE_SID/pdcsimage.dbf' SIZE 100M REUSE AUTOEXTEND ON NEXT 10M MAXSIZE 1G LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
      CREATE SMALLFILE TABLESPACE "PDCSTIDX" DATAFILE '$ORACLE_BASE/oradata/$ORACLE_SID/pdcstidx.dbf' SIZE 100M REUSE AUTOEXTEND ON NEXT 10M MAXSIZE 1G LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
      exit;
EOF"

  # Move database operational files to oradata
  moveFiles;
}

############# MAIN ################

# Set SIGTERM handler
trap _term SIGTERM

# Set SIGKILL handler
trap _kill SIGKILL

# Check whether database already exists
if [ -d $ORACLE_BASE/oradata/$ORACLE_SID ]; then
   symLinkFiles;
   # Make sure audit file destination exists
   if [ ! -d $ORACLE_BASE/admin/$ORACLE_SID/adump ]; then
      su -p oracle -c "mkdir -p $ORACLE_BASE/admin/$ORACLE_SID/adump"
   fi;
fi;

/etc/init.d/oracle-xe start | grep -qc "Oracle Database 11g Express Edition is not configured"
if [ "$?" == "0" ]; then
   # Check whether container has enough memory
   if [ `df -k /dev/shm | tail -n 1 | awk '{print $2}'` -lt 1048576 ]; then
      echo "Error: The container doesn't have enough memory allocated."
      echo "A database XE container needs at least 1 GB of shared memory (/dev/shm)."
      echo "You currently only have $((`df -k /dev/shm | tail -n 1 | awk '{print $2}'`/1024)) MB allocated to the container."
      exit 1;
   fi;
   
   # Create database
   createDB;
   _term;
   _kill;
   /etc/init.d/oracle-xe start
fi;

echo "#########################"
echo "DATABASE IS READY TO USE!"
echo "#########################"

tail -f $ORACLE_BASE/diag/rdbms/*/*/trace/alert*.log &
childPID=$!
wait $childPID
