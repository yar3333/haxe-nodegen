Tool to generate nodejs module from Haxe
========================================

DEPRECATED. Please, use `codegen` library.

Generate:

 * index.js - result of the compilation
 * index.d.ts - definitions file for using module from TypeScript
 * haxe externals - "extern" classes for using module from Haxe

Usage:
```shell
haxelib run nodegen [<options>] <package> <module> [ <project.hxproj> ] [ -- <haxe_compiler_options> ]
```
where `<options>` may be:

        <package>         Source haxe package to expose.

        <module>          Result node module name.
                          Specify '*' to use `name` field from the `package.json`.

        <hxproj>          FlashDevelop/HaxeDevelop project file ro read Haxe compiler options.

        -js               Destination file name for JavaScript. Like `index.js`.

        -hx               Destination directory for Haxe externals.
                          Use 'haxelib:' prefix to detect directory of specified Haxe library.

        -ts               Destination file name for TypeScript definitions. Like `index.d.ts`.

        --no-pre-build    Skip pre-build step from *.hxproj file.

        --no-post-build   Skip post-build step from *.hxproj file.

        --raw-haxe-module Haxe module name to copy to Haxe externals as is.
                          You can use this option several times.
                          Use 'file:' prefix to read module names from specified text file.

        --lazy            Skip building if source files are not changed from the last build.

        -v                Verbose.

Example:

```shell
haxelib run nodegen wquery hxnodejs-wquery --raw-haxe-module wquery.Macro -- -lib hant -cp src
```
