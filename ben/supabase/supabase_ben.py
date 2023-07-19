import psycopg2
import sys
from configparser import ConfigParser


def config(filename='database.ini', section='postgresql'):
    # create a parser
    parser = ConfigParser()
    # read config file
    parser.read(filename)

    # get section, default to postgresql
    db = {}
    if parser.has_section(section):
        params = parser.items(section)
        for param in params:
            db[param[0]] = param[1]
    else:
        raise Exception('Section {0} not found in the {1} file'.format(section, filename))

    return db

def update_job_queue(queue,socket):
    """ Connect to the PostgreSQL database server """
    conn = None
    try:
        # read connection parameters
        params = config()

        # connect to the PostgreSQL server
        print('Connecting to the PostgreSQL database...')
        conn = psycopg2.connect(**params)
		
        # create a cursor
        cur = conn.cursor()
        
	    # # execute a statement
        # print('PostgreSQL database version:')
        # cur.execute('SELECT * FROM "SchedulerJobs";')
        with open(queue, 'r') as file:
            next(file) # skip header line
            for line in file:
                line = line.strip()
                values = line.split()

                job_data = {
                    'job_id': '',
                    'output_dir': '',
                    'job_name': '',
                    'status': 'w',
                    'node_id': '-1',
                    'server': 'WAITING',
                    'duration': '-1',
                    'node_name': 'WAITING',
                    'socket': socket,
                }

                for i in range(min(len(values), len(job_data))):
                    column_name = list(job_data.keys())[i]
                    column_value = values[i]
                    job_data[column_name] = column_value

                try:
                    insert_query = '''
                        INSERT INTO "SchedulerJobs" (job_id, output_dir, job_name, status, node_id, server, node_name, duration, socket)
                        VALUES (%(job_id)s, %(output_dir)s, %(job_name)s, %(status)s, %(node_id)s, %(server)s, %(node_name)s, %(duration)s, %(socket)s)
                        ON CONFLICT (job_name) DO UPDATE
                        SET
                            output_dir = EXCLUDED.output_dir,
                            status = CASE WHEN "SchedulerJobs".status <> EXCLUDED.status THEN EXCLUDED.status ELSE "SchedulerJobs".status END,
                            node_id = EXCLUDED.node_id,
                            server = EXCLUDED.server,
                            node_name = EXCLUDED.node_name,
                            duration = EXCLUDED.duration,
                            socket = EXCLUDED.socket
                        WHERE "SchedulerJobs".status <> EXCLUDED.status;
                        '''
                    cur.execute(insert_query, job_data)
                    conn.commit()
                except Exception as e:
                    print(f"Error inserting data: {e}")
                    conn.rollback()
       
	# close the communication with the PostgreSQL
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
            print('Database connection closed.')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Please provide the path to the queue file and ben socket.")
        sys.exit(1)
    
    queue = sys.argv[1]
    socket= sys.argv[2]
    update_job_queue(queue,socket)
