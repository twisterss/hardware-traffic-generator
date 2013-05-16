from .modifier import Modifier, registerModifier
from ..fields import BitsField, UnsignedField, PacketField


class SkeletonSender(Modifier):
	"""
	Modifier definition
	"""
	def __init__(self, flow, options):
		"""
		Modifier options
		"""
		super().__init__(flow, "Skeleton sender", "Base packet data, to be completed and edited by modifiers", options)
		# Fields list
		self._addFields([
			UnsignedField(bitSize = 32,
				fieldId = "iterations",
				minimum = 1,
				name = "Iterations", 
				description = "Number of packets sent",
				editable = True,  
				default = 1),
			BitsField(bitSize = 13),
			UnsignedField(bitSize = 11,
				fieldId = "size",
				name = "Data size",
				description = "Number of bytes for 1 packet",
				default = 64),
			PacketField(bitSize = 64*8,
				fieldId = "data",
				minSize = 64*8,
				maxSize = 1522*8,
				name = "Data",
				description = "Base packet data",
				editable = True)
		])
		# Remember some fields
		self.__sizeField = self.getField("size")
		self.__packetField = self.getField("data")
		# Watch packet size changes
		self.__packetField.sizeChangeEvent+= self.__onPacketSizeChange
		self.__onPacketSizeChange()

	def __onPacketSizeChange(self, *args, **kwargs):
		"""
		Set the size field value
		"""
		self.__sizeField.autoValue = self.__packetField.byteSize


registerModifier('skeleton_sender', SkeletonSender, mandatory = True)