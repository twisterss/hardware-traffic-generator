from math import ceil
from ..exceptions import FieldError
from ..events import Event

class Field:
	"""
	Generic configuration field.
	This class is abstract and inherited by each field.
	It represents a field of a given size in the configuration.
	A field has a default value, and may be edited directly by bits.
	Subclasses give ways to manipulate the field value that are simpler
	than directly by bits.
	This ability may be given to the user too by setting editable to true.
	"""

	# Events
	valueChangeEvent = Event("the bytes value has changed")
	sizeChangeEvent = Event("the size has changed")
	autoChangeEvent = Event("the value has switched between user and auto")

	def __init__(self, bitSize, fieldId, name, description, editable, inConfig, minSize = None, maxSize = None):
		"""
		bitSize: initial size of the field in bits (mandatory)
		fieldId: string identifier unique to this field for one modifier (mandatory if editable)
		name: name of this field (mandatory if editable)
		description: description of this field (mandatory if editable)
		editable: can the field be edited by the user in an other way than by bits?
		inConfig: should this field be saved as a part of the configuration?
			If not, it is just an input field, which value can be read by the modifier.
		minSize: minimum size of the field (default: bitSize)
		maxSize: maximum size of the field (default: bitSize)
		"""
		# Check and remember arguments
		self.__defaultBitSize = bitSize
		self.__bitSize = bitSize
		if editable and (fieldId is None or name is None or description is None):
			raise FieldError(self, "editable fields should have an identifier, a name and a description")
		self.__id = fieldId
		if name is None:
			name = ""
		self.__name = name
		if description is None:
			description = ""
		self.__description = description
		self.__editable = editable
		self.__inConfig = inConfig
		if minSize is None:
			minSize = bitSize
		if maxSize is None:
			maxSize = bitSize
		if minSize < 0 or minSize > maxSize or bitSize < minSize or bitSize > maxSize:
			raise FieldError(self, "field size options are invalid")
		self.__minSize = minSize
		self.__maxSize = maxSize
		# Initialize internal state
		self.__auto = True
		self.__byteValue = None
		self.__autoByteValue = bytearray(self.byteSize)

	def reset(self):
		"""
		Resets the value of this field to its default value.
		Fields should probably override this to add their own behaviour.
		"""
		# Resets values to default
		self.bitSize = self.__defaultBitSize
		self.autoBytes = bytearray()
		self.auto = True
		# Unsets the user value: will be set by the user
		self.__byteValue = None

	def updateField(self, field):
		"""
		Updates the value of this field with the
		values of the given field.
		Override to add field-specific behaviour if needed.
		"""
		self.bitSize = field.bitSize
		self.userBytes = field.userBytes
		self.autoBytes = field.autoBytes
		self.auto = field.auto

	@property
	def id(self):
		"""
		Field identifier (string unique for 1 modifier)
		"""
		return self.__id

	@property 
	def type(self):
		"""
		Field type (class name)
		"""
		return type(self).__name__

	@property 
	def name(self):
		"""
		Field name 
		"""
		return self.__name

	@property 
	def description(self):
		"""
		Field description 
		"""
		return self.__description

	@property
	def editable(self):
		"""
		Can the field value be edited by the user
		by an other way than just changing bits?
		"""
		return self.__editable

	@property
	def inConfig(self):
		"""
		Should this field be saved as a part
		of the configuration?
		If not, it is just an input field,
		which value can be read by the modifier.
		"""
		return self.__inConfig

	@property
	def bitSize(self):
		"""
		Bit size of this field
		"""
		return self.__bitSize

	@bitSize.setter
	def bitSize(self, value):
		"""
		Modify the bit size of this field
		"""
		if value == self.__bitSize:
			return
		if value > self.__maxSize or value < self.__minSize:
			raise FieldError(self, "unauthorized field size")
		self.__bitSize = value
		# Adjust byteValue size
		byteSize = self.byteSize
		if self.__byteValue is not None:
			length = len(self.__byteValue)
			if length > byteSize:
				self.__byteValue = self.__byteValue[-byteSize:]
			elif length < byteSize:
				self.__byteValue = bytearray(byteSize-length) + self.__byteValue
		# Adjust autoByteValue size
		length = len(self.__autoByteValue)
		if length > byteSize:
			self.__autoByteValue = self.__autoByteValue[-byteSize:]
		elif length < byteSize:
			self.__autoByteValue = bytearray(byteSize-length) + self.__autoByteValue
		# Fire size change event, not value change
		self.sizeChangeEvent()

	@property
	def minBitSize(self):
		"""
		Minimum bit size
		"""
		return self.__minSize

	@property
	def maxBitSize(self):
		"""
		Maximum bit size
		"""
		return self.__maxSize

	@property
	def byteSize(self):
		"""
		Number of bytes of this field.
		Some bits may be unused
		"""
		return int(ceil(float(self.bitSize)/8))

	@property
	def auto(self):
		"""
		Is this field value an automatic value?
		"""
		return self.__auto

	@auto.setter
	def auto(self, value):
		"""
		Swith the value of this field between automatic and user value
		"""	
		if value == self.__auto:
			return
		self.__auto = value	
		# Fire events
		self.autoChangeEvent()
		if self.__autoByteValue != self.__byteValue:
			self.valueChangeEvent()

	def getBytes(self, auto = False):
		"""
		Get a copy of the current user or auto value 
		as a byte array.
		The user value is copied from the auto value if never set.
		"""
		value = None
		if auto:
			value = self.__autoByteValue
		else:
			if self.__byteValue is None:
				self.__byteValue = bytearray(self.__autoByteValue)
			value = self.__byteValue	
		return bytearray(value)

	def setBytes(self, value, auto = False):
		"""
		Set the current user or auto value 
		as a byte array
		"""
		toChange = None
		if auto:
			toChange = self.__autoByteValue
		else:
			if self.__byteValue is None:
				self.__byteValue = bytearray(self.__autoByteValue)
			toChange = self.__byteValue
		valueLen = len(value)
		for i in range(0, self.byteSize):
			if valueLen > i:
				toChange[i] = value[i]
			else:
				toChange[i] = 0
		# Fire the change event
		if auto == self.auto:
			self.valueChangeEvent()

	@property
	def bytes(self):
		"""
		Get the current value (user or automatic) of
		the field as a byte array.
		"""
		return self.getBytes(self.auto)

	@property
	def userBytes(self):
		"""
		Get the current user value of
		the field as a byte array.
		"""
		return self.getBytes(False)

	@userBytes.setter
	def userBytes(self, value):
		"""
		Set a new user value to the bytes 
		of this field.
		"""
		self.setBytes(value, False)

	@property
	def autoBytes(self):
		"""
		Get the current automatic value of
		the field as a byte array.
		"""
		return self.getBytes(True)

	@autoBytes.setter
	def autoBytes(self, value):
		"""
		Set a new automatic value to the bytes 
		of this field.
		"""
		self.setBytes(value, True)

	@property
	def strValue(self):
		"""
		String representation of the value
		if it can be given simply.
		Otherwise none.
		(To override)
		"""
		return None




