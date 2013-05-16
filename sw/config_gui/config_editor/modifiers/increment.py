from .modifier import Modifier, registerModifier
from ..fields import BitsField, UnsignedField, PacketField, SelectField

class Increment(Modifier):
	"""
	Modifier definition
	"""
	def __init__(self, flow, options):
		"""
		Modifier options
		"""
		super().__init__(flow, "Increment", "Set data at a configured offset to incrementing values", options)
		# Fields list
		self._addFields([
			UnsignedField(bitSize = 16,
				fieldId = "min",
				name = "Minimum", 
				description = "Minimum counter value",
				editable = True,  
				default = 0),
			UnsignedField(bitSize = 16,
				fieldId = "max",
				name = "Maximum", 
				description = "Maximum counter value",
				editable = True,  
				default = 255),
			UnsignedField(bitSize = 16,
				fieldId = "skip",
				name = "Change skip period", 
				description = "Packets skipped between each value change",
				editable = True,  
				default = 0),
			SelectField(bitSize = 1,
				fieldId = "mode",
				options = {"Increment": b'\x00', "Decrement": b'\x01'},
				name = "Count mode",
				description = "Increment or decrement the field",
				editable = True,
				default = b'\x00'),
			BitsField(bitSize = 7),
			UnsignedField(bitSize = 16,
				fieldId = "step",
				minimum = 1,
				name = "Increment value", 
				description = "Value added or removed at each step",
				editable = True,  
				default = 1),
			UnsignedField(bitSize = 11,
				fieldId = "offset",
				name = "Field offset", 
				description = "Offset in bytes from packet start",
				editable = True,  
				default = 0),
			BitsField(bitSize = 37)
		])

registerModifier('increment', Increment)