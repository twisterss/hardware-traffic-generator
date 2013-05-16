from .modifier import Modifier, registerModifier
from ..fields import BitsField, UnsignedField, PacketField, SelectField

class Checksum(Modifier):
	"""
	Modifier definition
	"""
	def __init__(self, flow, options):
		"""
		Modifier options
		"""
		super().__init__(flow, "Checksum", "Computes a checksum value and sets it", options)
		# Fields list
		self._addFields([
			UnsignedField(bitSize = 11,
				fieldId = "start-offset",
				name = "Data start offset", 
				description = "Offset of the first byte to compute the checksum on",
				editable = True,  
				default = 0),
			UnsignedField(bitSize = 11,
				fieldId = "end-offset",
				name = "Data end offset", 
				description = "Offset of the last byte to compute the checksum on",
				editable = True,
				default = 2047),
			UnsignedField(bitSize = 11,
				fieldId = "value-offset",
				maximum = 1521,
				name = "Value offset", 
				description = "Offset of first byte to put the checksum value",
				editable = True,
				default = 0),
			UnsignedField(bitSize = 11,
				fieldId = "ip-offset",
				name = "IP header offset", 
				description = "Offset of first byte of the IP header, if any",
				editable = True,
				default = 0),
			SelectField(bitSize = 2,
				fieldId = "type",
				options = {"None": b'\x00', "IPv4": b'\x01', "IPv6": b'\x02'},
				name = "Pseudo-header",
				description = "Type of the pseudo-header to include in the Checksum computation, if any",
				editable = True,
				default = b'\x00'),
			BitsField(bitSize = 10)
		])

registerModifier('checksum', Checksum)