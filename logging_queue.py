import queue
import asyncio
import logging
from logging.handlers import QueueHandler, QueueListener
from contextlib import contextmanager


class LocalQueueHandler(QueueHandler):
	def emit(self, record: logging.LogRecord) -> None:
		# There is no need to self.prepare() records that go into a local, in-process queue.
		# We can skip that process and further minimise the cost of logging.
		try:
			self.enqueue(record)
		except asyncio.CancelledError:
			raise
		except Exception:
			self.handleError(record)


def setup_logging_queue(name=None, local=False):
	logger = logging.getLogger(name)

	# Remove logger's current handlers to pass them to the queue listener
	handlers = []
	for handler in logger.handlers[:]:
		logger.removeHandler(handler)
		handlers.append(handler)

	# Log to a queue instead of doing blocking I/O
	que = queue.SimpleQueue()  # fast reentrant queue implementation without task tracking (not needed for logging)
	logger.addHandler(LocalQueueHandler(que) if local else QueueHandler(que))

	if not handlers:
		handler = logging.StreamHandler()
		handler.setLevel(logging.DEBUG)
		handler.setFormatter(logging.Formatter('%(asctime)s [%(name)s] %(levelname)s: %(message)s'))
		handlers.append(handler)
		logger.warning(f'No log handler provided. Using default. Logger level = {logging.getLevelName(logger.level)}')

	# Set up a listener that will monitor the queue and run the blocking I/O in a separate thread 
	return QueueListener(que, *handlers, respect_handler_level=True)


@contextmanager
def listen(listener):
	listener.start()
	try:
		yield listener
	finally:
		listener.stop()


if __name__ == '__main__':
	async def test_coro():
		logging.info('Waiting...')
		logging.info(await asyncio.sleep(1, 'Finished!'))

	logging.basicConfig(level=logging.DEBUG, format='%(asctime)s [%(module)s, %(lineno)d] %(levelname)s: %(message)s')
	log_listener = setup_logging_queue(local=True)

	with listen(listener=log_listener):
		asyncio.run(test_coro())
