import hant.FileSystemTools;
import hant.FlashDevelopProject;
import hant.CmdOptions;
import hant.Haxelib;
import hant.Log;
import hant.Process;
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
using StringTools;
using Lambda;

class Main 
{
	static function main() 
	{
        var args = Sys.args();
		
		//var exeDir = Path.normalize(Sys.getCwd());
		
		if (args.length > 0)
		{
			var dir = args.pop();
			try
			{
				Sys.setCwd(dir);
			}
			catch (e:Dynamic)
			{
				fail("Error: could not change dir to '" + dir + "'.");
			}
		}
        
		var options = new CmdOptions();
		
		options.add("package", "", "Source haxe package to expose.");
		options.add("module", "", "Result node module name.\nSpecify '*' to use `name` field from the `package.json`.");
		options.add("hxproj", "", "FlashDevelop/HaxeDevelop project file ro read Haxe compiler options.");
		options.add("jsFile", "", [ "-js" ], "Destination file name for JavaScript. Like `index.js`.");
		options.add("hxDir", "", [ "-hx" ], "Destination directory for Haxe externals.\nUse 'haxelib:' prefix to detect directory of specified Haxe library.");
		options.add("tsFile", "", [ "-ts" ], "Destination file name for TypeScript definitions. Like `index.d.ts`.");
		options.add("noPreBuild", false, [ "--no-pre-build" ], "Skip pre-build step from *.hxproj file.");
		options.add("noPostBuild", false, [ "--no-post-build" ], "Skip post-build step from *.hxproj file.");
		options.addRepeatable("rawHaxeModules", String, [ "--raw-haxe-module" ], "Haxe module name to copy to Haxe externals as is.\nYou can use this option several times.\nUse 'file:' prefix to read module names from specified text file.");
		options.add("lazy", false, [ "--lazy" ], "Skip building if source files are not changed from the last build.");
		options.add("verbose", false, [ "-v" ], "Verbose.");
		
		if (args.length > 0 && (args.length != 1 || args[0] != "--help"))
		{
			var compilerOptions = [];
			var sep = args.indexOf("--");
			if (sep >= 0)
			{
				compilerOptions = args.splice(sep + 1, args.length - sep - 1);
				args.pop(); // remove "--"
			}
			
			options.parse(args);
			
			var pack : String = options.get("package");
			if (pack == "") fail("<package> argument must be specified.");
			
			var module : String = options.get("module");
			if (module == "") fail("<module> argument must be specified.");
			if (module == "*") module = readModuleNameFromPackageJson();
			
			var hxproj : String = options.get("hxproj");
			if (hxproj.endsWith("*.hxproj")) hxproj = detectHxprojFilePath(hxproj);
			else if (hxproj == "") hxproj = null;
			
			var noPreBuild = options.get("noPreBuild");
			var noPostBuild = options.get("noPostBuild");
			
			var lazy : Bool = options.get("lazy");
			var verbose : Bool = options.get("verbose");
			
			if (Haxelib.getPath("codegen") == null)
			{
				if (Process.run("haxelib", [ "install", "codegen" ]).exitCode != 0) return 2;
				Sys.println("");
			}
			
			try
			{
				var project = hxproj != null ? FlashDevelopProject.load(hxproj) : null;
				if (project == null) project = new FlashDevelopProject();
				project.outputType = "Application";
				project.platform = "JavaScript";
				project.additionalCompilerOptions = project.additionalCompilerOptions.concat(compilerOptions);
				
				if (noPreBuild) project.preBuildCommand = "";
				if (noPostBuild) project.postBuildCommand = "";
				
				var lastModificationOfSources = lazy ? getLastModificationOfSources(project) : null;
				
				if (options.get("jsFile") != "")
				{
					var r = buildJavaScript(project, pack, options.get("jsFile"), lastModificationOfSources);
					if (r != 0) return r;
				}
				
				if (options.get("hxDir") != "")
				{
					var hxDir : String = options.get("hxDir");
					if (hxDir.startsWith("haxelib:")) hxDir = Haxelib.getPath(hxDir.substring("haxelib:".length));
					
					var rawHaxeModulesOriginal : Array<String> = options.get("rawHaxeModules");
					var rawHaxeModules = [];
					for (s in rawHaxeModulesOriginal)
					{
						if (s.startsWith("file:")) rawHaxeModules = rawHaxeModules.concat(readLinesFromFile(s.substring("file:".length)));
						else rawHaxeModules.push(s);
					}
					
					var r = buildHaxeExternals(project, pack, hxDir, module, rawHaxeModules, lastModificationOfSources, verbose);
					if (r != 0) return r;
				}
				
				if (options.get("tsFile") != "")
				{
					var r = buildTypeScript(project, pack, options.get("tsFile"), lastModificationOfSources, verbose);
					if (r != 0) return r;
				}
				
				return 0;
			}
			catch (e:AmbiguousProjectFilesException)
			{
				Sys.println("ERROR: " + e.message);
			}
		}
		else
		{
			Sys.println("nodegen is a tool to build nodejs modules.");
			Sys.println("Usage: haxelib run nodegen [<options>] <package> <module> [ <project.hxproj> ] [ -- <haxe_compiler_options> ]");
			Sys.println("where <options> may be:");
			Sys.println(options.getHelpMessage());
		}
		
		return 1;
	}
	
	static function buildJavaScript(project:FlashDevelopProject, pack:String, destFile:String, lastModificationOfSources:Date)
	{
		project.outputPath = fixPathDueProjectDirectory(project, destFile);
		
		Sys.print("Build JavaScript to \"" + destFile + "\":");
		
		if (lastModificationOfSources != null)
		{
			if (FileSystem.exists(destFile) && FileSystem.stat(destFile).mtime.getTime() >= lastModificationOfSources.getTime())
			{
				Sys.println(" SKIP");
				Sys.println("");
				return 0;
			}
		}
		
		Sys.println("");
		
		var r = project.build
		([
			"-lib", "nodegen",
			"--macro", "nodegen.Macro.expose('" + pack + "','')",
			"--macro", "include('" + pack + "')"
		]);
		
		Sys.println("");
		
		return r;
	}
	
	static function buildHaxeExternals(project:FlashDevelopProject, pack:String, destDirectory:String, module:String, rawModules:Array<String>, lastModificationOfSources:Date, verbose:Bool)
	{
		var destPackDir = Path.join([ destDirectory, pack.replace(".", "/") ]);
		
		Sys.print("Build Haxe externals to \"" + destPackDir + "\":");
		
		if (lastModificationOfSources != null)
		{
			var destFileLastDate = getLastModificationOfDir(destPackDir);
			if (destFileLastDate != null && destFileLastDate.getTime() >= lastModificationOfSources.getTime())
			{
				Sys.println(" SKIP");
				Sys.println("");
				return 0;
			}
		}
		
		Sys.println("");
		
		FileSystemTools.deleteDirectory(destPackDir, false);
		
		var options = [ "-lib", "codegen" ];
		if (verbose) options = options.concat([ "--macro", "CodeGen.set('verbose', true)" ]);
		options = options.concat
		([
			"--macro", "CodeGen.set('outPath', '" + fixPathDueProjectDirectory(project, destDirectory) + "')",
			"--macro", "CodeGen.set('applyNatives', false)",
			"--macro", "CodeGen.include('" + pack + "')",
			"--macro", "CodeGen.exclude('" + rawModules.join(",") + "')",
			"--macro", "CodeGen.set('includePrivate', true)",
			"--macro", "CodeGen.set('requireNodeModule', '" + module + "')",
			"--macro", "CodeGen.generate('haxeExtern')",
			"--macro", "include('" + pack + "')"
		]);
		
		
		var r = project.build(options);
		if (r != 0) return r;
		
		for (rawModule in rawModules)
		{
			var relPath = rawModule.replace(".", "/") + ".hx";
			var srcPath = project.findFile(relPath);
			if (srcPath != null) FileSystemTools.copyFile(srcPath, Path.join([ destDirectory, relPath ]), true);
		}
		
		Sys.println("");
		
		return 0;
	}
	
	static function buildTypeScript(project:FlashDevelopProject, pack:String, destFile:String, lastModificationOfSources:Date, verbose:Bool)
	{
		Sys.print("Build TypeScript definitions to \"" + destFile + "\":");
		
		if (lastModificationOfSources != null)
		{
			if (FileSystem.exists(destFile) && FileSystem.stat(destFile).mtime.getTime() >= lastModificationOfSources.getTime())
			{
				Sys.println(" SKIP");
				Sys.println("");
				return 0;
			}
		}
		
		Sys.println("");
		
		var options = [ "-lib", "codegen" ];
		if (verbose) options = options.concat([ "--macro", "CodeGen.set('verbose', true)" ]);
		options = options.concat
		([
			"--macro", "CodeGen.set('outPath', '" + fixPathDueProjectDirectory(project, destFile) + "')",
			"--macro", "CodeGen.set('applyNatives', false)",
			"--macro", "CodeGen.include('" + pack + "')",
			"--macro", "CodeGen.set('includePrivate', true)",
			"--macro", "CodeGen.map('" + pack + "', '')",
			"--macro", "CodeGen.generate('typescriptExtern')",
			"--macro", "include('" + pack + "')"
		]);
		
		var r = project.build(options);
		
		Sys.println("");
		
		return r;
	}
	
	static function readLinesFromFile(filePath:String)
	{
		var text = File.getContent(filePath);
		text = text.replace("\r\n", "\n").replace("\r", "\n");
		var lines = text.split("\n");
		lines = lines.map(StringTools.trim);
		lines = lines.filter(function(s) return s != "");
		return lines;
	}
	
	static function readModuleNameFromPackageJson() : String
	{
		if (!FileSystem.exists("package.json")) fail("Problem to fill <module> argument: can't find `package.json` in the current directory.");
		var json = Json.parse(File.getContent("package.json"));
		if (json == null || json.name == null || json.name == "") fail("Problem to fill <module> argument: field `name` in the `package.json` not exist or empty.");
		return json.name;
	}
	
	static function detectHxprojFilePath(maskPath:String) : String
	{
		var dir = Path.directory(maskPath);
		var files = FileSystem.readDirectory(dir).filter(function(x) return x.endsWith(".hxproj"));
		if (files.length == 0) fail("Problem detecting *.hxproj: no files found.");
		if (files.length > 1) fail("Problem detecting *.hxproj: several files found.");
		return Path.join([ dir, files[0] ]);
	}
	
	static function getLastModificationOfSources(project:FlashDevelopProject) : Date
	{
		var r = Date.fromTime(0);
		
		for (path in project.getAllClassPaths(false))
		{
			var d = getLastModificationOfDir(fixPathDueProjectDirectory2(project, path));
			if (d != null && d.getTime() > r.getTime()) r = d;
		}
		
		return r;
	}
	
	static function getLastModificationOfDir(path:String) : Date
	{
		if (!FileSystem.exists(path)) return null;
		
		var r = FileSystem.stat(path).mtime;
		
		FileSystemTools.findFiles
		(
			path,
			function(file)
			{
				var d = FileSystem.stat(file).mtime;
				if (d.getTime() > r.getTime()) r = d;
			},
			function(dir)
			{
				var d = FileSystem.stat(dir).mtime;
				if (d.getTime() > r.getTime()) r = d;
				
				return true;
			},
			false
		);
		
		return r;
	}
	
	static function fixPathDueProjectDirectory(project:FlashDevelopProject, path:String) : String
	{
		if (Path.isAbsolute(path)) return path;
		if (project.projectFilePath == null || project.projectFilePath == "") return path;
		var dir = Path.directory(project.projectFilePath);
		if (dir == "") return path;
		return FileSystem.absolutePath(path);
	}
	
	static function fixPathDueProjectDirectory2(project:FlashDevelopProject, path:String) : String
	{
		if (Path.isAbsolute(path)) return path;
		if (project.projectFilePath == null || project.projectFilePath == "") return path;
		var dir = Path.directory(project.projectFilePath);
		if (dir == "") return path;
		return Path.join([ dir, path ]);
	}
	
	static function fail(message:String)
	{
		Sys.println("ERROR: " + message);
		Sys.exit(1);
	}
}
