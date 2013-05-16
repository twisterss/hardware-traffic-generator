from .modifier import Modifier, registerModifier
from ..fields import BitsField, UnsignedField, PacketField, SelectField

class Rate(Modifier):
	"""
	Modifier definition
	"""
	def __init__(self, flow, options):
		"""
		Modifier options
		"""
		super().__init__(flow, "Rate", "Limits the rate of a flow", options)
		# Minimum inter-frame gap (bytes)
		self.__minGap = 12
		# Maximum rate (including min. gap and preamble)
		self.__maxRate = 10000
		# Fields list
		self._addFields([
			UnsignedField(bitSize = 32,
				fieldId = "rate",
				minimum = 1,
				maximum = self.__maxRate,
				name = "Data rate (Mb/s)", 
				description = "Bit rate of this flow on the link",
				editable = True,
				inConfig = False,
				default = self.__maxRate),
			UnsignedField(bitSize = 32,
				fieldId = "gap",
				minimum = self.__minGap,
				name = "Inter-frame gap (bytes)", 
				description = "Delay to wait for between 2 frames (time needed to send N bytes on the link)",
				editable = True,  
				default = self.__minGap),
			BitsField(bitSize = 24)
		])
		# Remember some fields (including one from the skeleton sender)
		self.__rateField = self.getField('rate')
		self.__gapField = self.getField('gap')
		self.__sizeField = self.flow.getModifierByType("skeleton_sender").getField("size")
		# Set the event listeners
		self.__rateField.valueChangeEvent+= self.__onRateChange
		self.__gapField.valueChangeEvent+= self.__onGapChange
		self.__sizeField.valueChangeEvent+= self.__setGapFromRate
		self.__sizeField.valueChangeEvent+= self.__setRateFromGap
		self.__rateField.autoChangeEvent+= self.__onAutoChange
		self.__gapField.autoChangeEvent+= self.__onAutoChange

	def __onAutoChange(self, *args):
		"""
		Detects when both fields are on auto:
		default value
		"""
		if self.__rateField.auto and self.__gapField.auto:
			# Set both field to their default value
			self.__gapField.autoValue = None
			self.__rateField.autoValue = None

	def __onGapChange(self, *args, **kwargs):
		"""
		The gap was changed by the user
		"""
		if not self.__gapField.auto:
			self.__setRateFromGap()
			self.__rateField.auto = True

	def __onRateChange(self, *args, **kwargs):
		"""
		The rate was changed by the user
		"""
		if not self.__rateField.auto:
			self.__setGapFromRate()
			self.__gapField.auto = True

	def __setGapFromRate(self, *args, **kwargs):
		"""
		Sets the gap value from the set rate
		"""
		# Wanted rate
		rate = self.__rateField.value
		# Data size
		minSize = self.__sizeField.value
		# + preamble and minimum gap
		minSize+= self.__minGap + 1
		size = int(round((minSize / rate) * self.__maxRate))
		gap = size - minSize + self.__minGap
		self.__gapField.autoValue = gap

	def __setRateFromGap(self, *args, **kwargs):
		"""
		Set the rate from the set gap value
		"""
		# Wanted gap
		gap = self.__gapField.value
		# Data size (with preamble)
		size = self.__sizeField.value + 1
		minSize = size + self.__minGap
		size+= gap
		rate = int(round((minSize * self.__maxRate) / size))
		self.__rateField.autoValue = rate










registerModifier('rate', Rate, mandatory = True)