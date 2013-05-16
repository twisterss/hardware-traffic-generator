import os.path
import json
import pickle
from .exceptions import ConfigError, ModifierError
from .flow_generator import FlowGenerator
from .modifiers import getModifier
from pprint import pprint

class Hardware:
	"""
	Represent the current hardware layout
	of the generator.
	May be exported to a generator configuration file.
	May be saved/loaded in a python format to a file.
	"""

	def __init__(self, hardwarePath):
		"""
		Initiates hardware from a hardware configuration file
		"""
		# File to which the file was saved
		self.__filename = None
		# List of flow generators
		self.__flows = []
		# Load the main configuration file
		hardwareFile = open(hardwarePath)
		hardwareConfig = json.load(hardwareFile)
		if 'flow_generator' not in hardwareConfig or type(hardwareConfig['flow_generator']) is not dict:
			raise ConfigError(hardwarePath, 'flow_generator', 'should be a dictionnary')
		flowConfig = hardwareConfig['flow_generator']
		# Number of instances of flow generators
		if 'instances' not in flowConfig or type(flowConfig['instances']) is not int or flowConfig['instances'] < 1:
			raise ConfigError(hardwarePath, 'instances', 'should be an integer of 1 or more')
		instances = flowConfig['instances']
		# List of modifiers
		if 'modifiers' not in flowConfig or type(flowConfig['modifiers']) is not list:
			raise ConfigError(hardwarePath, 'modifiers', 'should be a list')
		modifiersConfig = flowConfig['modifiers']
		for index in range(0, instances):
			generator = FlowGenerator()
			self.__flows.append(generator)
			for modifierConfig in modifiersConfig:
				if type(modifierConfig) is not dict:
					raise ConfigError(hardwarePath, 'modifiers', 'items in the list should be dictionnaries')
				if 'type' not in modifierConfig or type(modifierConfig['type']) is not str:
					raise ConfigError(hardwarePath, 'type', 'should contain the modifier type name')
				if 'config' not in modifierConfig or type(modifierConfig['config']) is not dict:
					raise ConfigError(hardwarePath, 'config', 'should contain the modifier configuration dictionnary')
				modClass = getModifier(modifierConfig['type'])
				if modClass is None:
					raise ConfigError(hardwarePath, 'type', modifierConfig['type'] + " is an unknown modifier type")
				generator.addModifier(modClass(generator, modifierConfig['config']))
		# Initialize
		self.__initState()

	def reset(self):
		"""
		Resets the values configured on this hardware 
		"""
		for i, flow in enumerate(self.__flows):
			flow.reset()
		self.__initState()

	def __initState(self):
		"""
		Initial state (1 flow enabled)
		"""
		self.__flows[0].enabled = True

	@property
	def flows(self):
		"""
		Get the list of flow generators
		"""
		return self.__flows

	@property
	def configData(self):
		"""
		Get the configuration data 
		"""
		data = ""
		for i, flow in enumerate(self.__flows):
			if flow.enabled:
				data+= "--------------------\n"
				data+= "-- Flow " + str(i+1) + "\n"
				if flow.description:
					data+= "-- \n"
					for line in flow.description.split("\n"):
						data+= "-- " + line + "\n"
				data+= "--------------------\n"				
				data+= flow.configData
		return data

	def exportConfig(self, filename):
		"""
		Export the configuration to a file
		"""
		with open(filename, 'w') as configFile:
				configFile.write(self.configData)

	@property
	def filename(self):
		"""
		Get the filename for saving, if any
		"""
		return self.__filename

	def saveTo(self, filename):
		"""
		Saves the current configuration to a specified file
		"""
		self.__filename = filename
		return self.save()

	def save(self):
		"""
		Saves the current configuration to the known file
		"""
		if self.__filename is None:
			return False
		try:
			with open(self.__filename, 'wb') as saveFile:
				pickle.dump(self, saveFile)
		except:
			return False
		return True

	def load(self, filename):
		"""
		Loads the configuration from a given file.
		Tries to adapt to different hardware nicely
		"""
		hardware = None
		try:
			with open(filename, 'rb') as saveFile:
				hardware = pickle.load(saveFile)
		except:
			return False
		for i, flow in enumerate(hardware.flows):
			if len(self.__flows) <= i:
				break
			# Copy flow properties
			myFlow = self.__flows[i]
			myFlow.enabled = flow.enabled
			try:
				myFlow.description = flow.description
			except AttributeError:
				myFlow.description = ""
			# Copy modifier properties
			for modifier in flow.modifiers:
				try:
					self.__flows[i].updateModifier(modifier)
				except ModifierError:
					# If the modifier could not be replaced, ignore it
					pass
		# Remember the file name
		self.__filename = filename
		return True







