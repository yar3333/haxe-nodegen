Tool to generate nodejs module from Haxe
========================================

Generate:

 * index.js - result of the compilation
 * index.d.ts - definitions file for using module from TypeScript
 * haxe externals - "extern" classes for using module from Haxe

Usage:
```shell
haxelib run nodegen [<options>] <package> <module> [ -- <haxe_compiler_options> ]
```
where `<options>` may be:

	--no-haxe        Don't generate haxe externals.
	--no-typescript  Don't generate typescript definitions.
	--ignore-hxproj  Don't read haxe options from hxproj file.
	                 Default is read *.hxproj from the current directory if exactly one exists.
	--dest-directory Destination directory. Default is 'hxnodejs'.
	--raw-module     Haxe module name to copy to haxe externals as is. You can use this option several times.
	<package>        Source haxe package to expose.
	<module>         Result nodejs module name.
	
`nodegen` read `*.hxproj` from the current directory and use classpaths and libraries from it.
If you don't use HaxeDevelop/FlashDevelop - just specify `-cp` and `-lib` haxe compiler options in `<haxe_compiler_options>` agrument.

Example:

```shell
haxelib run nodegen wquery hxnodejs-wquery --raw-module wquery.Macro -- -lib hant -cp src
```
