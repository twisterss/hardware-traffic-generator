from PyQt4 import QtGui

from .modifiers_container import ModifiersContainer
from .modifier_widget import ModifierWidget

class FlowWidget(QtGui.QWidget):
	"""
	Widget representing the configuration of 1 flow generator
	"""

	def __init__(self, flow):
		"""
		Takes the flow that should be configured
		"""
		super().__init__()
		self.__flow = flow
		self.__descField = None
		# initialize the UI
		self.__initUI()
		# Bind the events
		flow.enabledChangeEvent+= self.__setEnabledStatus
		flow.descriptionChangeEvent+= self.__getDescription
		self.__descField.textChanged.connect(self.__setDescription)

	def __initUI(self):
		"""
		Initialize the GUI
		"""
		# Main layout
		vbox = QtGui.QVBoxLayout()
		self.setLayout(vbox)
		# Add the description box
		descLabel = QtGui.QLabel("Description:")
		self.__descField = QtGui.QTextEdit()
		self.__descField.setAcceptRichText(False)
		self.__descField.setMaximumHeight(50)
		vbox.addWidget(descLabel)
		vbox.addWidget(self.__descField)
		self.__getDescription()
		# Create the tabs widget
		tabs = QtGui.QTabWidget()
		vbox.addWidget(tabs)
		# Show one tab per mandatory modifier
		# and one tab for other modifiers
		otherModifiers = []
		for modifier in self.__flow.modifiers:
			if modifier.mandatory:
				tabs.addTab(ModifierWidget(modifier), modifier.name)
			else:
				otherModifiers.append(modifier)
		if otherModifiers:
			tabs.addTab(ModifiersContainer(otherModifiers), "Modifiers")
		# Set the state
		self.__setEnabledStatus()

	def __setEnabledStatus(self, *args):
		"""
		Enable or disable the widget depending on the flow
		"""
		self.setEnabled(self.__flow.enabled)

	def __setDescription(self, *args):
		"""
		Sets the description from the field 
		"""
		self.__flow.description = self.__descField.toPlainText()

	def __getDescription(self, *args):
		"""
		Gets the description in the field 
		"""
		if self.__descField.toPlainText() != self.__flow.description:
			self.__descField.setPlainText(self.__flow.description)



