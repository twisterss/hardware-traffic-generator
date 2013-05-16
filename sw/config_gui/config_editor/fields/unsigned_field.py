from .field import Field
from ..exceptions import FieldError

class UnsignedField(Field):
	"""
	Field represented as an unsigned integer.
	Supports up to 64 bits wide.
	Byte 0 is the least significant byte.
	The most significant bits of the most significant byte may be unused.
	"""
	def __init__(self, bitSize, fieldId = None, minimum = None, maximum = None, name = None, description = None, editable = False, inConfig = True, default = 0):
		"""
		bitSize should be at most 64.
		default should be an integer.
		"""
		super().__init__(bitSize, fieldId, name, description, editable, inConfig)
		if bitSize > 64:
			raise FieldError(self, "size should be at most 64 bits")
		if minimum is None:
			minimum = 0
		if maximum is None:
			maximum = (1 << bitSize) - 1
		if default < minimum or default > maximum:
			raise FieldError(self, "default value should be between the minimum and maximum")
		self.__min = minimum
		self.__max = maximum
		# Set the auto value to default
		self.__default = default
		self.autoValue = None

	@property
	def minimum(self):
		"""
		Minimum value to set
		"""
		return self.__min

	@property
	def maximum(self):
		"""
		Maximum value to set
		"""
		return self.__max

	def reset(self):
		"""
		Resets the value of this field to its default value.
		"""
		super().reset()
		# Sets the auto value to its default value
		self.autoValue = None

	def __getValue(self, auto = False):
		"""
		Get the integer value (auto or user)
		"""
		bytes = self.getBytes(auto)
		size = self.byteSize
		value = 0
		for i in range(0, size):
			value += bytes[i] * (1 << (8*i));
		return value

	def __setValue(self, value, auto = False):
		"""
		Set the integer value (auto or user)
		Set to Null to set the default value.
		"""
		if value is None:
			value = self.__default
		if value == self.__getValue(auto):
			return
		if value < self.__min or value > self.__max:
			raise FieldError(self, "value should be between the minimum and maximum")
		bytes = self.getBytes(auto)
		size = self.byteSize
		for i in range(0, size):
			bytes[i] = (value >> (8*i)) & 0xFF;
		self.setBytes(bytes, auto)

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
		return str(self.value)