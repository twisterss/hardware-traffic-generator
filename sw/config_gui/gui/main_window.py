from PyQt4 import QtGui, QtCore
from os.path import expanduser

from .flow_widget import FlowWidget

class MainWindow(QtGui.QMainWindow):
	"""
	Main configuration window: to open first
	"""
	def __init__(self, hardware):
		"""
		Take an hardware configuration path to show its configuration
		"""
		super().__init__()
		self.__hardware = hardware
		self.__flowSelector = None
		self.__flowEnabler = None
		self.__newAction = None
		self.__saveAction = None
		self.__saveAsAction = None
		self.__openAction = None
		self.__exitAction = None
		self.__exportAction = None
		self.__flowWidgets = []
		self.__visibleFlowWidget = None
		self.__mainWidget = None
		# initialize the UI
		self.__initUI()

	def __initUI(self):
		"""
		Initialize the GUI
		"""
		# Create the main menu
		self.__createMenu()
		# Initialize the hardware GUI part
		self.__initHardwareUI()

		# Window size
		self.resize(500, 300)
		# Center the window
		geo = self.frameGeometry()
		geo.moveCenter(QtGui.QDesktopWidget().availableGeometry().center())
		self.move(geo.topLeft())
        # Title
		self.setWindowTitle("Traffic generator")

	def __initHardwareUI(self):
		"""
		Initialize the part of the GUI that depends from hardware.
		Overrides the current GUI if any
		"""
		vbox = QtGui.QVBoxLayout()
		# Add the flow selection area
		flowSelectArea = self.__createFlowSelectArea()
		vbox.addLayout(flowSelectArea)
		# Add the flow configuration widgets
		self.__createFlowWidgets(vbox)
		vbox.addStretch(1)
		# Create the main widget
		self.__mainWidget = QtGui.QWidget()
		self.__mainWidget.setLayout(vbox)
		self.setCentralWidget(self.__mainWidget)
		# Set all events
		self.__flowSelector.currentIndexChanged.connect(self.__onFlowSelectorChanged)
		self.__flowEnabler.stateChanged.connect(self.__onFlowEnablerChanged)
		self.__newAction.triggered.connect(self.__onNew)
		self.__saveAction.triggered.connect(self.__onSave)
		self.__saveAsAction.triggered.connect(self.__onSaveAs)
		self.__openAction.triggered.connect(self.__onOpen)
		self.__exitAction.triggered.connect(QtGui.qApp.quit)
		self.__exportAction.triggered.connect(self.__onExportConfig)
		for flow in self.__hardware.flows:
			flow.enabledChangeEvent+= self.__updateFlowSelectArea

	def __createMenu(self):
		"""
		Create the main menu 
		"""
		self.__newAction = QtGui.QAction('&New', self)        
		self.__newAction.setShortcut('Ctrl+N')
		self.__openAction = QtGui.QAction('&Open...', self)        
		self.__openAction.setShortcut('Ctrl+O')
		self.__saveAction = QtGui.QAction('&Save', self)
		self.__saveAction.setShortcut('Ctrl+S')
		self.__saveAsAction = QtGui.QAction('Save &As...', self)
		self.__saveAsAction.setShortcut('Ctrl+Shift+S')
		self.__exitAction = QtGui.QAction('&Exit', self)        
		self.__exitAction.setShortcut('Ctrl+Q')
		self.__exportAction = QtGui.QAction('&Export to File', self)        
		self.__exportAction.setShortcut('Ctrl+E')

		menu = self.menuBar()
		fileMenu = menu.addMenu('&File')
		fileMenu.addAction(self.__newAction)
		fileMenu.addAction(self.__openAction)
		fileMenu.addAction(self.__saveAction)
		fileMenu.addAction(self.__saveAsAction)
		fileMenu.addAction(self.__exitAction)
		configMenu = menu.addMenu('&Configuration')
		configMenu.addAction(self.__exportAction)

	def __createFlowSelectArea(self):
		"""
		Create the flow selector, returned as a layout
		"""
		# Elements
		self.__flowSelector = QtGui.QComboBox()
		self.__flowEnabler = QtGui.QCheckBox("Enable this flow")
		self.__updateFlowSelectArea()
		# Layout
		hbox = QtGui.QHBoxLayout()
		hbox.addWidget(QtGui.QLabel("Current flow: "))
		hbox.addWidget(self.__flowSelector)
		hbox.addStretch(1)
		hbox.addWidget(self.__flowEnabler)
		return hbox

	def __updateFlowSelectArea(self, *args, **kwargs):
		"""
		Fills the flow selector choices
		and updates the enabled flow.
		"""
		# Choices
		flowCount = 0
		for flow in self.__hardware.flows:
			text = "Flow " + str(flowCount+1) + " ("
			if flow.enabled:
				text+= "enabled"
			else:
				text+= "disabled"
			text+= ")"
			if self.__flowSelector.count() <= flowCount:
				self.__flowSelector.addItem(text, flow)
			else:
				self.__flowSelector.setItemText(flowCount, text)
			flowCount+= 1
		# Enabled
		self.__flowEnabler.setChecked(self.__currentFlow.enabled)

	def __createFlowWidgets(self, layout):
		"""
		Creates flow widgets and adds them to the layout 
		"""
		for flow in self.__hardware.flows:
			flowWidget = FlowWidget(flow)
			self.__flowWidgets.append(flowWidget)
			layout.addWidget(flowWidget)
			flowWidget.hide()
		self.__showFlowWidget()

	def __showFlowWidget(self):
		"""
		Sets the current flow widget as visible
		"""
		toShow = self.__currentFlowWidget
		if toShow is self.__visibleFlowWidget:
			return
		if self.__visibleFlowWidget is not None:
			self.__visibleFlowWidget.hide()
		toShow.show()
		self.__visibleFlowWidget = toShow


	def __onFlowSelectorChanged(self, currentIndex):
		"""
		Other flow selected
		"""
		self.__updateFlowSelectArea()
		self.__showFlowWidget()

	def __onFlowEnablerChanged(self, state):
		"""
		Flow enabled or disabled
		"""
		self.__currentFlow.enabled = self.__flowEnabler.isChecked()
		self.__updateFlowSelectArea()

	def __onNew(self):
		"""
		Start a new configuration
		"""
		self.__hardware.reset()

	def __onOpen(self):
		"""
		Start a loaded configuration
		"""
		filename = QtGui.QFileDialog.getOpenFileName(self, 'Open Configuration', expanduser('~/config.gcf'), 'Configuration file (*.gcf)')
		if filename != '':
			self.__hardware.load(filename)

	def __onSave(self):
		"""
		Saves current configuration
		"""
		if not self.__hardware.save():
			self.__onSaveAs()

	def __onSaveAs(self):
		"""
		Saves current configuration with a new file name
		"""
		filename = QtGui.QFileDialog.getSaveFileName(self, 'Save Configuration', expanduser('~/config.gcf'), 'Configuration file (*.gcf)')
		if filename != '':
			self.__hardware.saveTo(filename)

	def __onExportConfig(self):
		"""
		Export the current configuration
		"""
		filename = QtGui.QFileDialog.getSaveFileName(self, 'Export to File', expanduser('~/config.txt'), 'Text file (*.txt)')
		if filename != '':
			self.__hardware.exportConfig(filename)

	@property 
	def __currentFlow(self):
		"""
		Flow currently configured
		"""
		return self.__flowSelector.itemData(self.__flowSelector.currentIndex())

	@property 
	def __currentFlowWidget(self):
		"""
		Flow widget currently active
		"""
		return self.__flowWidgets[self.__flowSelector.currentIndex()]