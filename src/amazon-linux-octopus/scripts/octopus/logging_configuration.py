import logging
import sys

def configure(log_file_name):
    if log_file_name == None:
        log_file_name = '/var/log/octopus-python-scripts.log'
    
    root = logging.getLogger()
    root.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    stdoutHandler = logging.StreamHandler(sys.stdout)
    stdoutHandler.setLevel(logging.INFO)
    stdoutHandler.setFormatter(formatter)
    root.addHandler(stdoutHandler)

    fileHandler = logging.FileHandler(filename=log_file_name, encoding='utf-8')
    fileHandler.setLevel(logging.DEBUG)
    fileHandler.setFormatter(formatter)
    root.addHandler(fileHandler)

    return log_file_name