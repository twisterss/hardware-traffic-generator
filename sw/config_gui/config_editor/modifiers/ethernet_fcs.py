from .modifier import Modifier, registerModifier

class EthernetFCS(Modifier):
	"""
	Ethernet FCS modifier
	"""
	def __init__(self, flow, options):
		"""
		No specific option for this modifier 
		"""
		super().__init__(flow, "Ethernet FCS", "Overrides the 4 last bytes of the packet with the computed Ethernet FCS value.", options)

registerModifier('ethernet_fcs', EthernetFCS)