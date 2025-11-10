class_name TextData
extends Resource

## 纯文本
@export_multiline var text : String
## 国际化key
@export var internationalization_key : String

## 根据是否国际化的配置返回显示文本
func get_text() -> String:
	return text
