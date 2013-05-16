from PyQt4 import QtGui

from .modifier_widget import ModifierWidget

class ModifiersContainer(QtGui.QWidget):
	"""
	Container with a list of modifiers to configure
	"""
	def __init__(self, modifiers):
		"""
		Take the hardware representation to show its configuration
		"""
		super().__init__()
		self.__modifiers = modifiers
		self.__selector = None
		self.__enabler = None
		self.__modifierWidgets = []
		self.__visibleModifierWidget = None
		# initialize the UI
		self.__initUI()
		# Set the events
		self.__selector.currentIndexChanged.connect(self.__onSelectorChanged)
		self.__enabler.stateChanged.connect(self.__onEnablerChanged)
		for modifier in self.__modifiers:
			modifier.enabledChangeEvent+= self.__updateSelectArea

	def __initUI(self):
		"""
		Initialize the GUI
		"""
		mainBox = QtGui.QVBoxLayout()
		# Add the modifier selection area
		selectArea = self.__createSelectArea()
		mainBox.addLayout(selectArea)
		mainBox.addStretch(1)
		# Add the modifer configuration widgets
		configBox = QtGui.QVBoxLayout()
		self.__createModifierWidgets(configBox)
		configGroup = QtGui.QGroupBox("Configuration")
		configGroup.setLayout(configBox)
		mainBox.addWidget(configGroup)
		self.setLayout(mainBox)

	def __createSelectArea(self):
		"""
		Create the modifer selector, returned as a layout
		"""
		# Elements
		self.__selector = QtGui.QComboBox()
		self.__enabler = QtGui.QCheckBox("Enable")
		self.__updateSelectArea()
		# Layout
		hbox = QtGui.QHBoxLayout()
		hbox.addWidget(QtGui.QLabel("Modifier: "))
		hbox.addWidget(self.__selector)
		hbox.addStretch(1)
		hbox.addWidget(self.__enabler)
		return hbox

	def __updateSelectArea(self, *args, **kwargs):
		"""
		Fills the modifier selector choices
		and updates the enabled modifier.
		"""
		# Choices
		count = 0
		for modifier in self.__modifiers:
			text = str(modifier.id) + ": " + modifier.name + " ("
			if modifier.enabled:
				text+= "enabled"
			else:
				text+= "disabled"
			text+= ")"
			if self.__selector.count() <= count:
				self.__selector.addItem(text, modifier)
			else:
				self.__selector.setItemText(count, text)
			count+= 1
		# Enabled
		self.__enabler.setChecked(self.__currentModifier.enabled)

	def __createModifierWidgets(self, layout):
		"""
		Creates modifier widgets and adds them to the layout 
		"""
		for modifier in self.__modifiers:
			modifierWidget = ModifierWidget(modifier)
			self.__modifierWidgets.append(modifierWidget)
			layout.addWidget(modifierWidget)
			modifierWidget.hide()
		self.__showModifierWidget()

	def __showModifierWidget(self):
		"""
		Sets the current modifier widget as visible
		"""
		toShow = self.__currentModifierWidget
		if toShow is self.__visibleModifierWidget:
			return
		if self.__visibleModifierWidget is not None:
			self.__visibleModifierWidget.hide()
		toShow.show()
		self.__visibleModifierWidget = toShow


	def __onSelectorChanged(self, currentIndex):
		"""
		Other modifier selected
		"""
		self.__updateSelectArea()
		self.__showModifierWidget()

	def __onEnablerChanged(self, state):
		"""
		Modifier enabled or disabled
		"""
		self.__currentModifier.enabled = self.__enabler.isChecked()
		self.__updateSelectArea()

	@property 
	def __currentModifier(self):
		"""
		Flow currently configured
		"""
		return self.__selector.itemData(self.__selector.currentIndex())

	@property 
	def __currentModifierWidget(self):
		"""
		Flow widget currently active
		"""
		return self.__modifierWidgets[self.__selector.currentIndex()]