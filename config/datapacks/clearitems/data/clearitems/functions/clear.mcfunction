kill @e[type=item]
tellraw @a {"text":"Oe Papi, pendiente que se va a borrar todo (se limpiaron los items del suelo)","color":"red"}
schedule function clearitems:announce 72000t replace
