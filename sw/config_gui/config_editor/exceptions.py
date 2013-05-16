class ConfigError(Exception):
	"""
	Error in a configuration file
	"""

	def __init__(self, filePath, key, message):
		self.__filePath = filePath
		self.__key = key
		self.__message = message

	def __str__(self):
		return self.__filePath + ": " + self.__key + ": " + self.__message

class FieldError(Exception):
	"""
	Error in values received by a field
	"""

	def __init__(self, field, message):
		self.__field = field
		self.__message = message

	def __str__(self):
		name = self.__field.name
		if name == "":
			name = "Field"
		return name + " (" + self.__field.type + "): " + self.__message

class ModifierError(Exception):
	"""
	Error in values received by a modifer
	"""

	def __init__(self, modifier, message):
		self.__modifier = modifier
		self.__message = message

	def __str__(self):
		return self.__modifier.name + " (" + str(self.__modifier.id) + "): " + self.__message

class ExtendError(Exception):
	"""
	Error in the way the code got extended to add
	new modifiers or fields...
	"""

	def __init__(self, message):
		self.__message = message

	def __str__(self):
		return self.__message