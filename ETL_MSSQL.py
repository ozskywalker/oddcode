#!/usr/bin/python3
import pyodbc

# Install libraries:
# apt-get update && apt-get -y install freetds-dev freetds-bin unixodbc-dev tdsodbc && pip3 install pyodbc

# Configure ODBC:
# cat > /etc/odbcinst.ini
# [FreeTDS]
# Description=FreeTDS Driver
# Driver=/usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so
# Setup=/usr/lib/x86_64-linux-gnu/odbc/libtdsS.so

# then...

# odbcinst -q -d -i -f /etc/odbcinst.ini 

# Now validate.
# Validate script:

# import pyodbc
# conn = pyodbc.connect('DRIVER=FreeTDS;SERVER=172.19.157.209\COMMVAULT;DATABASE=CommServ;UID=change_me;PWD=change_me;TDS_Version=8.0;')
# cursor = conn.cursor()
# for row in cursor.execute('select 6 * 7 as [Result];'):
#     print(row.Result)

datawarehouse_name = 'test2'

source_connection_string = 'DRIVER=FreeTDS;SERVER=hostname\instance;DATABASE=test1;UID=change_me;PWD=change_me;TDS_Version=8.0;'
target_connection_string = 'DRIVER=FreeTDS;SERVER=hostname\instance;DATABASE=test2;UID=change_me;PWD=change_me;TDS_Version=8.0;'

source_extract_query = "select [key], value from t1"
target_load_query = "insert into t1 ([key], value) values (?, ?)"

# exporting queries
class SqlQuery:
	extract_query = ''
	load_query = ''
	def __init__(self, extract_query, load_query):
		self.extract_query = extract_query
		self.load_query = load_query

def etl(query, source_cnx, target_cnx):
	source_cursor = source_cnx.cursor()
	source_cursor.execute(query.extract_query)
	data = source_cursor.fetchall()
	source_cursor.close()
	if data:
		target_cursor = target_cnx.cursor()
		target_cursor.fast_executemany = False
		target_cursor.execute("USE {};".format(datawarehouse_name))
		target_cursor.executemany(query.load_query, data)
		target_cursor.commit()
		print('data loaded to warehouse db')
		target_cursor.close()
	else:
		print('data is empty')

source_cnx = pyodbc.connect(source_connection_string)
target_cnx = pyodbc.connect(target_connection_string)

query = SqlQuery(source_extract_query, target_load_query)
etl(query, source_cnx, target_cnx)

target_cnx.close()
source_cnx.close()
