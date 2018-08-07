##
## ***Always be logging***
##
import traceback
import logging
from logging.handlers import RotatingFileHandler

# Logging defaults - basic config will log to stdout, then we'll add a log-to-file handler
# Allow log override from environ variable
FILE_LOG_FORMAT = "%(asctime)s %(levelname)s %(module)s:%(lineno)d %(message)s"
#CONSOLE_LOG_FORMAT = "%(levelname)s %(module)s:%(lineno)d %(message)s"
CONSOLE_LOG_FORMAT = FILE_LOG_FORMAT
LOG_FILENAME = __file__ + '.log'

LOG_LEVEL = os.getenv('LOG_LEVEL', logging.INFO)
if LOG_LEVEL == 'debug':
    LOG_LEVEL=logging.DEBUG

# setup for console
logging.basicConfig(level=LOG_LEVEL, format=CONSOLE_LOG_FORMAT)
logger = logging.getLogger('')

# setup for file
log_file_handler = RotatingFileHandler(LOG_FILENAME, maxBytes=20971520, backupCount=5)
log_file_handler.setFormatter(logging.Formatter(FILE_LOG_FORMAT))
logger.addHandler(log_file_handler)
##
##
##