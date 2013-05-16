"""
Enables some very simple event-driven programming
without main loop (no threading)
"""

class Event:
	"""
	Event definition as a class attribute
	"""

	def __init__(self, doc = None, **argsDoc):
		"""
		doc: reason for which the event is fired
		argsDoc: dictionnary of argument names and their documentation
		"""
		# Construct a clear documentation
		fullDoc = "Event handler: use += to add a callback, -= to remove it, and (...) to fire the event."
		if doc is not None:
			fullDoc+= "\nEvent reason: " + doc + "."
		fullDoc+= "\nCallback arguments:"
		fullDoc+= "\n\tsender: instance that fired the callback"
		for argName, argDoc in argsDoc.items():
			fullDoc+= "\n\t" + argName + ": " + argDoc
		self.__doc__ = fullDoc
		# Initialize handlers list
		self.__handlers = {}

	def __get__(self, inst, instClass):
		"""
		Return a handler specific to this instance
		"""
		if inst is None:
			return self
		if inst not in self.__handlers:
			self.__handlers[inst] = EventHandler(inst)
		return self.__handlers[inst]

	def __set__(self, obj, value):
		"""
		Neutralize the setter
		"""
		pass

class EventHandler:
	"""
	Event handler that keeps a list of callbacks
	"""

	def __init__(self, instance):
		"""
		Remembers the instance that fires this event 
		"""
		self.__instance = instance
		self.__callbacks = []

	def __iadd__(self, callback):
		"""
		Add a callback in the list: operator +=
		"""
		self.__callbacks.append(callback)

	def __isub__(self, callback):
		"""
		Remove a callback from the list: operator -=
		"""
		self.__callbacks.remove(callback)

	def __call__(self, *args, **kwargs):
		"""
		Call all callbacks: makes the handler callable
		"""
		for callback in self.__callbacks:
			callback(self.__instance, *args, **kwargs)
