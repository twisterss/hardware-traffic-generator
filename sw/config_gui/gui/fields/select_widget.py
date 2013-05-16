from PyQt4 import QtGui
from .common import registerFieldWidget

class SelectWidget(QtGui.QWidget):
	"""
	Represents a select field
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
		self.__input.currentIndexChanged.connect(self.__onInputChanged)
		self.__defaultCheck.stateChanged.connect(self.__onDefaultCheckChanged)
		self.__field.autoChangeEvent+= self.__onFieldAutoChanged
		self.__field.valueChangeEvent+= self.__onFieldValueChanged

	def __initUI(self):
		"""
		Initialize the GUI
		"""
		hbox = QtGui.QHBoxLayout()
		hbox.addWidget(QtGui.QLabel(self.__field.name + ": "))
		hbox.addStretch(1)
		self.__input = QtGui.QComboBox()
		for name, value in self.__field.options.items():
			self.__input.addItem(name, value)
		hbox.addWidget(self.__input)
		self.__defaultCheck = QtGui.QCheckBox("auto")
		hbox.addWidget(self.__defaultCheck)
		self.setLayout(hbox)
		# Set default values
		self.__input.setCurrentIndex(self.__input.findText(self.__field.value))
		self.__defaultCheck.setChecked(self.__field.auto)

	def __onInputChanged(self):
		"""
		Input value changed 
		"""
		self.__field.userValue = self.__input.currentText()
		self.__field.auto = False

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

	def __onFieldValueChanged(self, *args):
		"""
		The field auto mode has changed 
		"""
		self.__input.blockSignals(True)
		self.__input.setCurrentIndex(self.__input.findText(self.__field.value))
		self.__input.blockSignals(False)

registerFieldWidget("SelectField", SelectWidget)