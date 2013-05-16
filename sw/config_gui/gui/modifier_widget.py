from PyQt4 import QtGui
from .fields import getFieldWidget

class ModifierWidget(QtGui.QWidget):
	"""
	Widget that contains the configuration for 1 modifer
	"""

	def __init__(self, modifier):
		"""
		Takes the modifer that should be configured
		"""
		super().__init__()
		self.__modifier = modifier
		# initialize the UI
		self.__initUI()
		# Bind the events
		modifier.enabledChangeEvent+= self.__setEnabledStatus

	def __initUI(self):
		"""
		Initialize the GUI
		"""
		vbox = QtGui.QVBoxLayout()
		# Description
		description = QtGui.QLabel(self.__modifier.description)
		description.setWordWrap(True)
		vbox.addWidget(description)
		vbox.addStretch(1)
		# Add each editable field (if known)
		for field in self.__modifier.fields:
			if field.editable:
				widgetClass = getFieldWidget(field.type)
				if widgetClass is not None:
					vbox.addWidget(widgetClass(field))
		# Layout
		self.setLayout(vbox)
		# Status
		self.__setEnabledStatus()

	def __setEnabledStatus(self, *args):
		"""
		Enable or disable the widget depending on the modifier
		"""
		self.setEnabled(self.__modifier.enabled)