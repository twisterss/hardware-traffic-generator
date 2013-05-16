from .field import Field

class BitsField(Field):
	"""
	This field is defined simply by bits
	"""
	def __init__(self, bitSize, fieldId = None, name = None, description = None, editable = False, inConfig = True, default = None):
		"""
		Default should be a bytearray.
		If it is None, all bits will be 0.
		"""
		super().__init__(bitSize, fieldId, name, description, editable, inConfig)
		if default is not None:
			self.autoBytes = bytearray(default)