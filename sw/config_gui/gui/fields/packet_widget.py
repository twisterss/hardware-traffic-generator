import re

from PyQt4 import QtGui
from .common import registerFieldWidget

class PacketWidget(QtGui.QWidget):
	"""
	Represents packet data.
	For now only the length of a field with 0s can be set.
	"""

	def __init__(self, field):
		"""
		Takes the flow that should be configured
		"""
		super().__init__()
		self.__field = field
		self.__input = None
		self.__defaultCheck = None
		# initialize the UI
		self.__initUI()
		# Bind events
		self.__input.textChanged.connect(self.__onInputChanged)
		self.__defaultCheck.stateChanged.connect(self.__onDefaultCheckChanged)
		self.__field.valueChangeEvent+= self.__onFieldChanged
		self.__field.autoChangeEvent+= self.__onFieldAutoChanged
		self.__input.oldFocusOutEvent = self.__input.focusOutEvent
		self.__input.focusOutEvent = self.__inputFocusOutEvent


	def __initUI(self):
		"""
		Initialize the GUI
		"""
		hbox = QtGui.QHBoxLayout()
		hbox.addWidget(QtGui.QLabel(self.__field.name + ": "))
		hbox.addStretch(1)
		self.__input = QtGui.QTextEdit()
		self.__input.setAcceptRichText(False)
		self.__input.setMaximumHeight(100)
		hbox.addWidget(self.__input)
		self.__defaultCheck = QtGui.QCheckBox("auto")
		hbox.addWidget(self.__defaultCheck)
		self.setLayout(hbox)
		# Set initial value
		self.__setFieldText()
		self.__defaultCheck.setChecked(self.__field.auto)

	@property
	def __inputValue(self):
		"""
		Returns the input value tranformed into bytes.
		The transformation is very permissive and succeeds every time.
		"""
		text = self.__input.toPlainText()
		text = re.sub(r'[^a-fA-F0-9]', '', text)
		if len(text) % 2 != 0:
			text = text + "0"
		while len(text) * 4 < self.__field.minBitSize:
			text+= "00"
		text = text[0:int(self.__field.maxBitSize/4)]
		bytes = bytearray()
		for i in range(0, int(len(text)/2)):
			char = text[i*2:(i+1)*2]
			bytes.append(int(char, 16))
		return bytes

	@property
	def __fieldText(self):
		"""
		Returns the field value transformed into a text
		that can be displayed cleanly in the input
		"""
		bytes = self.__field.value
		count = 0
		text = ""
		for byte in bytes:
			if count > 0:
				if count % 8 == 0:
					text+= "\n"
				elif count % 4 == 0:
					text+= "\t"
				else:
					text+= " "
			text+= "%02x" % byte
			count+= 1
		return text

	def __setFieldText(self):
		"""
		Sets the filed text in the input, without firing events
		"""
		self.__input.blockSignals(True)
		self.__input.setPlainText(self.__fieldText)
		self.__input.blockSignals(False)

	def __onInputChanged(self, *args):
		"""
		Input value changed 
		"""
		self.__field.userValue = self.__inputValue
		self.__field.auto = False

	def __onFieldChanged(self, *args):
		"""
		Field changed
		"""
		if self.__inputValue != self.__field.value:
			self.__setFieldText()

	def __inputFocusOutEvent(self, event):
		"""
		Override the input focus out event
		to add value cleaning
		"""
		self.__input.oldFocusOutEvent(event)
		if self.__fieldText != self.__input.toPlainText():
			self.__setFieldText()

	def __onDefaultCheckChanged(self, *args):
		"""
		The default check has changed 
		"""
		self.__field.auto = self.__defaultCheck.isChecked()

	def __onFieldAutoChanged(self, *args):
		"""
		The field auto mode has changed 
		"""
		self.__defaultCheck.setChecked(self.__field.auto)


registerFieldWidget("PacketField", PacketWidget)