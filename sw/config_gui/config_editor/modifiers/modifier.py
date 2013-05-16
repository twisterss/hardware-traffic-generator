from math import ceil
from ..exceptions import ModifierError, ExtendError
from ..events import Event

class Modifier:
	"""
	Generic modifier: this is an abstact class.
	All modifiers should inherit from it.
	"""

	enabledChangeEvent = Event("the modifer has been enabled or disabled")

	def __init__(self, flow, name, description, options):
		"""
		Constructor with the parent flow, the name of the modifier,
		its description and an options dictionnary.
		Options are received from configuration. The identifier is 
		the only required option.
		"""
		# Remember parameters
		self.__flow = flow
		self.__name = name
		self.__description = description
		self.__id = 0
		if 'id' not in options or type(options['id']) != int:
			raise ModifierError(self, "The identifier should be set as an integer")
		self.__id = options['id']
		# Initialize
		self.__fields = []
		self.__enabled = False

	def reset(self):
		"""
		Resets the values of this modifier.
		Modifiers may override this to add custom behaviour.
		"""
		self.enabled = self.mandatory
		for field in self.__fields:
			field.reset()

	def updateModifier(self, modifier):
		"""
		Update the values of this modifier with the ones of the
		given modifier.
		Override to add modifier-specific behaviour if needed.
		"""
		# Enable or disable
		self.enabled = modifier.enabled
		# Updates each field with the same id
		# Ignores unknown fields
		for i, field in enumerate(modifier.fields):
			oldModifier = None
			if field.id is not None:
				oldModifier = self.getField(field.id)
			if oldModifier is not None:
				oldModifier.updateField(field)

	@property
	def flow(self):
		"""
		Flow of this modifier
		"""
		return self.__flow

	@property
	def name(self):
		"""
		Name of this modifier
		"""
		return self.__name

	@property
	def id(self):
		"""
		Identifier of this modifier (hardware identifier)
		"""
		return self.__id

	@property
	def description(self):
		"""
		Description of this modifier
		"""
		return self.__description

	@property
	def enabled(self):
		"""
		Is this modifier enabled? Mandatory modifiers are always enabled
		"""
		return self.mandatory or self.__enabled

	@enabled.setter
	def enabled(self, enabled):
		"""
		Set if this modifier is enabled.
		Impossible if this modifier is mandatory.
		"""
		if enabled == self.__enabled:
			return
		if self.mandatory and not enabled:
			raise ModifierError(self, "Mandatory modifiers may not be disabled")
		self.__enabled = enabled
		self.enabledChangeEvent()

	@property
	def fields(self):
		"""
		Get a copy of the fields list
		"""
		return list(self.__fields)

	def getField(self, fieldId):
		"""
		Returns the field with the given identifier.
		Or None if not found.
		"""
		for field in self.__fields:
			if field.id == fieldId:
				return field
		return None

	def _addFields(self, fields):
		"""
		Add fields (called by the subclass)
		"""
		# Check that each field id is unique
		for field in fields:
			if field.id is not None and self.getField(field.id) is not None:
				raise ModifierError(self, "The field identifier " + field.id + " is already used.")
		self.__fields+= fields

	@property 
	def bytes(self):
		"""
		Get the concatenated field bytes, with the identifier byte
		"""
		bytes = bytearray([self.__id])
		bitSize = 8
		for field in self.__fields:
			if field.inConfig:
				# Create space for the new field
				bytes+= bytearray(field.byteSize)
				# Add data byte by byte with the proper bit shift
				remainingBits = field.bitSize
				# The first (most significant) byte may have up to 7 empty bits
				emptyBits = field.byteSize * 8 - field.bitSize
				for byte in reversed(field.bytes):
					shift = (bitSize % 8) - emptyBits
					if shift == 0:
						bytes[int(bitSize/8)]|= byte
					elif shift > 0:
						bytes[int(bitSize/8)]|= byte >> shift
						bytes[int(bitSize/8)+1]|= (byte << (8 - shift)) & 0xFF
					else:
						bytes[int(bitSize/8)]|= byte << (-shift)
						bytes[int(bitSize/8)-1]|= (byte >> (8 + shift)) & 0xFF
					# Prepare for next byte
					bitSize+= 8 - emptyBits
					emptyBits = 0
		# Cuts useless bytes
		byteSize = int(ceil(float(bitSize)/8))
		bytes = bytes[:byteSize]
		return bytes

	@property
	def configData(self):
		"""
		Get the configuration data 
		"""
		# Comments
		data = "-- " + self.name + "\n"
		data+= "--------------------\n"
		data+= "-- Identifier: " + str(self.id) + "\n"
		for field in self.__fields:
			if field.strValue is not None:
				data+= "-- " + field.name + ": " + field.strValue + "\n"
		# Ensures data is in a multiple of 8 bytes
		bytes = self.bytes
		if len(bytes) % 8 > 0:
			bytes+= bytearray(8 - len(bytes) % 8)
		# Transforms data into hexadecimal values
		lines = []
		for i in range(0, int(ceil(len(bytes)/8))):
			for j in reversed(range(0, 2)):
				line = ""
				for k in range(0, 4):
					index = i * 8 + j * 4 + k
					line+= "%02X" % bytes[index]
				lines.append(line)
		data += "\n".join(lines)
		return data

# Modifiers that were declared and are available
__modifiers = {}

def registerModifier(modifierType, modifierClass, mandatory = False):
	"""
	Registers a new modifier type.
	The class will be instantiated for each modifer of this type.
	If the modifier is set as mandatory, a flow generator will have to
	include it at least once.
	"""
	# Add type and mandatory attributes to the class
	if hasattr(modifierClass, "type") and modifierClass.type != modifierType:
		raise ExtendError("A modifier class may not be used twice for different types")
	modifierClass.type = modifierType
	modifierClass.mandatory = mandatory
	# Put in the list
	__modifiers[modifierType] = modifierClass

def getModifier(modifierType):
	"""
	Returns the modifier class if it has been registered, or None
	"""
	if modifierType in __modifiers:
		return __modifiers[modifierType]
	return None

def getModifiers(mandatoryOnly = False):
	"""
	Returns a list of all modifier classes,
	or only mandatory ones
	"""
	modifiers = []
	for type, modClass in self.__modifiers:
		if not mandatoryOnly or modClass['mandatory']:
			modifiers << modClass
	return modifiers

