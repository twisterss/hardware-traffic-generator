from PyQt4 import QtGui
from .common import registerFieldWidget

class UnsignedWidget(QtGui.QWidget):
	"""
	Represents an unsigned integer in a field
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
		self.__input.valueChanged.connect(self.__onInputChanged)
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
		self.__input = QtGui.QDoubleSpinBox()
		self.__input.setDecimals(0)
		self.__input.setMinimum(self.__field.minimum)
		self.__input.setMaximum(self.__field.maximum)
		hbox.addWidget(self.__input)
		self.__defaultCheck = QtGui.QCheckBox("auto")
		hbox.addWidget(self.__defaultCheck)
		self.setLayout(hbox)
		# Set default values
		self.__input.setValue(self.__field.value)
		self.__defaultCheck.setChecked(self.__field.auto)

	def __onInputChanged(self):
		"""
		Input value changed 
		"""
		self.__field.userValue = int(self.__input.value())
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
		self.__input.setValue(self.__field.value)
		self.__input.blockSignals(False)

registerFieldWidget("UnsignedField", UnsignedWidget)