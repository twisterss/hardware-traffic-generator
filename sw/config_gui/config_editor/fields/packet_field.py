from .field import Field
from math import ceil

class PacketField(Field):
	"""
	Field represented as packet data.
	Will enable to add headers for some defined protocols
	"""
	def __init__(self, bitSize, minSize, maxSize, fieldId = None, name = None, description = None, editable = False, inConfig = True):
		"""
		bitSize: default size of the packet
		minSize: minimum size of the packet
		maxSize: maximum size of the packet
		"""
		super().__init__(bitSize, fieldId, name, description, editable, inConfig, minSize = minSize, maxSize = maxSize)

	def __getByteIndex(self, pos):
		"""
		Returns the index in the stored bytes
		from the position in the value
		"""
		word = int(pos / 8)
		offset = pos % 8
		start = word * 8
		wordLen = min(8, self.byteSize - start)
		newPos = start + wordLen - (offset+1)
		return self.byteSize - (newPos + 1)

	def __getValue(self, auto = False):
		"""
		Get the bytes value (auto or user)
		"""
		bytes = self.getBytes(auto)
		value = bytearray(self.byteSize)
		for pos in range(0, self.byteSize):
			value[pos] = bytes[self.__getByteIndex(pos)]
		return value

	def __setValue(self, value, auto = False):
		"""
		Set the bytes value (auto or user)
		"""
		self.bitSize = len(value) * 8
		bytes = bytearray(self.byteSize)
		for pos in range(0, self.byteSize):
			bytes[self.__getByteIndex(pos)] = value[pos]
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

