from .exceptions import ModifierError
from .events import Event

class FlowGenerator:
	"""
	Represents one flow generator with its modifiers
	"""

	enabledChangeEvent = Event("the flow has been enabled or disabled")
	descriptionChangeEvent = Event("the flow description has been changed")

	def __init__(self):
		self.__enabled = False
		# List with unique ids
		self.__modifiers = []
		self.__description = None

	def reset(self):
		"""
		Resets the values of this generator
		"""
		self.enabled = False
		for modifier in self.__modifiers:
			modifier.reset()

	@property
	def description(self):
		"""
		Flow description
		"""
		return self.__description

	@description.setter
	def description(self, description):
		"""
		Change the flow description
		"""
		if description == self.__description:
			return
		self.__description = description
		self.descriptionChangeEvent()

	@property
	def enabled(self):
		"""
		Is this flow generator active?
		"""
		return self.__enabled

	@enabled.setter
	def enabled(self, enabled):
		"""
		Change if this flow generator is active
		"""
		if enabled == self.__enabled:
			return
		self.__enabled = enabled
		self.enabledChangeEvent()

	def addModifier(self, modifier):
		"""
		Add a modifier to the flow generator 
		"""
		if self.getModifier(modifier.id) is not None:
			raise ModifierError(modifier, "the identifier is already used")
		self.__modifiers.append(modifier)

	def updateModifier(self, modifier):
		"""
		Update the values of an existing modifier in the flow generator.
		Only if the new modifier has the same id and type as an existing modifier
		"""
		currentModifier = self.getModifier(modifier.id)
		if type(currentModifier) is not type(modifier):
			raise ModifierError(modifier, "this modifier may not be used (different type for this id)")
		currentModifier.updateModifier(modifier)

	@property
	def modifiers(self):
		"""
		Get a copy of the modifiers list 
		"""
		return list(self.__modifiers)

	@property
	def enabled_modifiers(self):
		"""
		Get a copy of the enabled modifiers list 
		"""
		mods = []
		for modifier in self.__modifiers:
			if modifier.enabled:
				mods.append(modifier)
		return mods

	def getModifier(self, modId):
		"""
		Get the modifier of given id, or None
		"""
		for modifier in self.__modifiers:
			if modifier.id == modId:
				return modifier
		return None

	def getModifierByType(self, modType):
		"""
		Get the first modifier of given type, or None
		"""
		for modifier in self.__modifiers:
			if modifier.type == modType:
				return modifier
		return None

	@property
	def configData(self):
		"""
		Get the configuration data 
		"""
		data = ""
		modifiers = self.enabled_modifiers
		count = len(modifiers)
		for i, modifier in enumerate(reversed(modifiers)):
			if i < count - 1:
				data+= "00000000\n00000000\n$\n"
			else:
				data+= "FFFFFFFF\nFFFFFFFF\n$\n"
			data+= modifier.configData
			data+= "\n#\n"
		return data