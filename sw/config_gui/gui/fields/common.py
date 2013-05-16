__fieldWidgets = {}

def registerFieldWidget(fieldType, widgetClass):
	__fieldWidgets[fieldType] = widgetClass

def getFieldWidget(fieldType):
	if fieldType in __fieldWidgets:
		return __fieldWidgets[fieldType]
	return None