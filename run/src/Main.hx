import hant.FileSystemTools;
import hant.FlashDevelopProject;
import hant.CmdOptions;
import hant.Haxelib;
import hant.Log;
import hant.Process;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
using StringTools;

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
		options.add("module", "", "Result node module name.");
		options.add("jsFile", "", [ "-js" ], "Destination file name for JavaScript.");
		options.add("hxDir", "", [ "-hx" ], "Destination directory for Haxe externals.");
		options.add("tsFile", "", [ "-ts" ], "Destination file name for TypeScript definitions.");
		options.addRepeatable("rawHaxeModules", String, [ "--raw-haxe-module" ], "Haxe module name to copy to Haxe externals as is. You can use this option several times.");
		options.add("ignoreHxproj", false, [ "--ignore-hxproj" ], "Don't read haxe options from HaxeDevelop/FlashDevelop hxproj file.\nDefault is read *.hxproj from the current directory if exactly one exists.");
		
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
			
			if (options.get("package") == "") fail("<package> argument must be specified.");
			if (options.get("module") == "") fail("<module> argument must be specified.");
			
			if (Haxelib.getPath("codegen") == null)
			{
				Sys.println("");
				if (Process.run("haxelib", [ "install", "codegen" ]).exitCode != 0) return 2;
			}
			
			try
			{
				var project = !options.get("ignoreHxproj") ? FlashDevelopProject.load("") : null;
				if (project == null) project = new FlashDevelopProject();
				project.outputType = "Application";
				project.platform = "JavaScript";
				project.additionalCompilerOptions = project.additionalCompilerOptions.concat(compilerOptions);
				
				if (options.get("jsFile") != "")
				{
					var r = buildJavaScript(project, options.get("package"), options.get("jsFile"));
					if (r != 0) return r;
				}
				
				if (options.get("hxDir") != "")
				{
					var r = buildHaxeExternals(project, options.get("package"), options.get("hxDir"), options.get("module"), options.get("rawHaxeModules"));
					if (r != 0) return r;
				}
				
				if (options.get("tsFile") != "")
				{
					var r = buildTypeScript(project, options.get("package"), options.get("tsFile"));
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
			Sys.println("Usage: haxelib run nodegen [<options>] <package> <module> [ -- <haxe_compiler_options> ]");
			Sys.println("where <options> may be:");
			Sys.println(options.getHelpMessage());
		}
		
		return 1;
	}
	
	static function buildJavaScript(project:FlashDevelopProject, pack:String, destFile:String)
	{
		project.outputPath = destFile;
		
		Sys.println("\nBuild JavaScript to \"" + project.outputPath + "\":");
		
		return project.build
		([
			"-lib", "nodegen",
			"--macro", "nodegen.Macro.expose('" + pack + "','')",
			"--macro", "include('" + pack + "')"
		]);
	}
	
	static function buildHaxeExternals(project:FlashDevelopProject, pack:String, destDirectory:String, module:String, rawModules:Array<String>)
	{
		var destPackDir = Path.join([ destDirectory, pack.replace(".", "/") ]);
		
		Sys.println("\nBuild Haxe externals to \"" + destPackDir + "\":");
		
		FileSystemTools.deleteDirectory(destPackDir, false);
		
		var r = project.build
		([
			"-lib", "codegen",
			"--macro", "CodeGen.set('outPath', '" + destDirectory + "')",
			"--macro", "CodeGen.set('applyNatives', false)",
			"--macro", "CodeGen.include('" + pack + "')",
			"--macro", "CodeGen.exclude('" + rawModules.join(",") + "')",
			"--macro", "CodeGen.set('includePrivate', true)",
			"--macro", "CodeGen.set('requireNodeModule', '" + module + "')",
			"--macro", "CodeGen.generate('haxeExtern')",
			"--macro", "include('" + pack + "')"
		]);
		if (r != 0) return r;
		
		for (rawModule in rawModules)
		{
			var relPath = rawModule.replace(".", "/") + ".hx";
			var srcPath = project.findFile(relPath);
			if (srcPath != null) FileSystemTools.copyFile(srcPath, Path.join([ destDirectory, relPath ]), true);
		}
		
		return 0;
	}
	
	static function buildTypeScript(project:FlashDevelopProject, pack:String, destFile:String)
	{
		Sys.println("\nBuild TypeScript definitions to \"" + destFile + "\":");
		
		return project.build
		([
			"-lib", "codegen",
			"--macro", "CodeGen.set('outPath', '" + destFile + "')",
			"--macro", "CodeGen.set('applyNatives', false)",
			"--macro", "CodeGen.include('" + pack + "')",
			"--macro", "CodeGen.set('includePrivate', true)",
			"--macro", "CodeGen.map('" + pack + "', '')",
			"--macro", "CodeGen.generate('typescriptExtern')",
			"--macro", "include('" + pack + "')"
		]);
	}
	
	static function fail(message:String)
	{
		Sys.println("ERROR: " + message);
		Sys.exit(1);
	}
}
