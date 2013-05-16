from .field import Field
from ..exceptions import FieldError

class SelectField(Field):
	"""
	Field represented as a select between different choices.
	"""
	def __init__(self, bitSize, options, fieldId = None, name = None, description = None, editable = False, inConfig = True, default = None):
		"""
		options should be a dictionnary "string value" => bytearray value.
		The most significant bits of the most significant byte may be unused.
		default should be a string value in options. It will be the first option by default.
		"""
		super().__init__(bitSize, fieldId, name, description, editable, inConfig)
		# Check and remember options
		if type(options) is not dict or len(options) < 1:
			raise FieldError(self, "an options dictionnary with at least 1 option is required")
		self.__options = {}
		for name, value in options.items():
			if type(name) is not str:
				raise FieldError(self, "option names should be strings")
			if type(value) is not bytearray and type(value) is not bytes:
				raise FieldError(self, "option values should be bytes")
			if len(value) > self.byteSize:
				raise FieldError(self, "option values are too big.")
			convVal = bytearray(self.byteSize)
			for i, byte in enumerate(value):
				convVal[i] = byte
			self.__options[name] = convVal
		# Remember default value
		if default is None:
			self.__default = self.__options.values()[0]
		else:
			if type(default) is not bytearray and type(default) is not bytes:
				raise FieldError(self, "default value should be bytes")
			self.__default = default
		# Set the auto value to default
		self.autoValue = None

	@property
	def options(self):
		"""
		Copy of the options list
		"""
		return dict(self.__options)

	def reset(self):
		"""
		Resets the value of this field to its default value.
		"""
		super().reset()
		# Sets the auto value to its default value
		self.autoValue = None

	def __getValue(self, auto = False):
		"""
		Get the string value (auto or user)
		None if unknown value.
		"""
		bytes = self.getBytes(auto)
		for name, value in self.__options.items():
			if value == bytes:
				return name
		return None

	def __setValue(self, value, auto = False):
		"""
		Set the string value (auto or user).
		Set to Null to set the default value.
		"""
		if value is None:
			self.setBytes(self.__default, auto)
		else:
			self.setBytes(self.__options[value], auto)

	@property
	def value(self):
		"""
		Get the current value of this field (auto or user)
		"""
		return self.__getValue(self.auto)

	@property
	def userValue(self):
		"""
		Get the current user value of this field
		"""
		return self.__getValue()

	@userValue.setter
	def userValue(self, value):
		"""
		Set the current user value of this field
		"""
		self.__setValue(value)

	@property
	def autoValue(self):
		"""
		Get the current auto value of this field
		"""
		self.__getValue(True)

	@autoValue.setter
	def autoValue(self, value):
		"""
		Set the current auto value of this field
		"""
		self.__setValue(value, True)

	@property
	def strValue(self):
		"""
		String representation of the value.
		"""
		value = self.value
		if value is None:
			return "unknown"
		else:
			return value