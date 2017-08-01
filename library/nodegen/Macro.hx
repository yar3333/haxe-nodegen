package nodegen;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.PositionTools;
import haxe.macro.Type;
using haxe.macro.Tools;
using Lambda;
using StringTools;

class Macro
{

#if macro
	
	/**
	 * Compiler macro to expose all types from package recursively.
	 */
	public static function expose(pack:String, mapToPack:String=null)
	{
		Context.onGenerate(function(types)
		{
			for (type in types)
			{
				switch (type)
				{
					case Type.TInst(t, _): exposeType(pack, mapToPack, t.get());
					case Type.TEnum(t, _): exposeType(pack, mapToPack, t.get());
					case _:
				}
			}
		});
	}
	
	static function exposeType(pack:String, mapToPack:String, type:BaseType)
	{
		var fullName = type.pack.concat([type.name]).join(".");
		if ((fullName + ".").startsWith(pack + "."))
		{
			type.meta.remove(":expose");
			
			if (mapToPack == null)
			{
				type.meta.add(":expose", [], type.pos);
			}
			else
			{
				var newFullName = (mapToPack != "" ? mapToPack + "." : "") + fullName.substring(pack.length + 1);
				type.meta.add(":expose", [ macro $v{newFullName} ], type.pos);
			}
		}
	}
	
#end

}