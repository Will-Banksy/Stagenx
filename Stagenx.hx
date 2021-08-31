using StringTools;
using sys.io.File;
using haxe.Json;
using String;
using sys.FileSystem;

typedef BlogSpecJson = {
	var postLinkLists : Array<PostLinkListJson>;
	var files : Array<FileObjJson>;
}

typedef PostLinkListJson = {
	var template : String;
	var postsJson : String;
}

typedef FileObjJson = {
	var template : String;
	var scope : String;
	var filename : String;
}

typedef PostLinkList = {
	var template : String;
	var posts : Array<Post>;
}

typedef Post = {
	var title : String;
	var description : String;
	var date : String;
	var thumbnail : String;
	var content : String;
	var filename : String;
}

class Stagenx {
	static var outputDir : String = "";

	static public function main() {
		if(Sys.args().length == 0) {
			Sys.stderr().writeString("[ERROR]: Blog json file path unspecified");
			Sys.exit(1);
		}
		var blogJsonPath = Sys.args()[0];
		if(Sys.args().length > 1) {
			outputDir = Sys.args()[1];
		} else {
			outputDir = "output";
		}
		if(Sys.args().length > 2) {
			var workingDir = FileSystem.absolutePath(Sys.args()[2]);
			Sys.setCwd(workingDir); // Doesn't work in java
		}

		outputDir = FileSystem.absolutePath(outputDir);

		// Load the main json file
		var blogSpec : BlogSpecJson = Json.parse(File.getContent(FileSystem.absolutePath(blogJsonPath)));

		// Get all the post link lists
		var postLinkLists : Array<PostLinkList> = [];
		for(postLinkListJson in blogSpec.postLinkLists) {
			var postLinkList : PostLinkList = { template: "", posts: [] }; // Initialise anon struct. This isn't C++ there are no default constructors for everything
			postLinkList.template = content(postLinkListJson.template);
			postLinkList.posts = Json.parse(content(postLinkListJson.postsJson));
			postLinkLists.push(postLinkList);
		}

		// Copy the postLinkList template for each post (appending the copies to the template string) and do the replacements
		for(postLinkList in postLinkLists) {
			var postLinkListTemplateBuf = new StringBuf();
			for(post in postLinkList.posts) {
				post.content = content(post.content);
				var template = postLinkList.template;
				template = template.replace("${PostTitle}", post.title);
				template = template.replace("${PostDescription}", post.description);
				template = template.replace("${PostDate}", post.date);
				template = template.replace("${PostThumbnail}", post.thumbnail);
				template = template.replace("${PostContent}", post.content);
				template = template.replace("${PostFilename}", post.filename);
				postLinkListTemplateBuf.add(template);
			}
			postLinkList.template = postLinkListTemplateBuf.toString();
		}

		/* trace(postLinkLists); */

		// Make output directory if it doesn't exist
		if(!FileSystem.exists(outputDir)) {
			FileSystem.createDirectory(outputDir);
		} else if(!FileSystem.isDirectory(outputDir)) {
			Sys.stderr().writeString("[ERROR]: Cannot create output directory " + outputDir + " - Non-directory file with that path already exists");
			Sys.exit(1);
		}

		// Now handle each file
		for(fileObj in blogSpec.files) {
			fileObj.template = content(fileObj.template);
			if(fileObj.scope == "per-post") {
				for(postLinkList in postLinkLists) {
					for(post in postLinkList.posts) {
						var filepath = outputDir + "/" + fileObj.filename.replace("${PostFilename}", post.filename);
						var template = fileObj.template;
						template = processIncludes(template); // Resolve includes *before* doing any other replacements, so the included files will have their content replaced too
						template = template.replace("${PostTitle}", post.title);
						template = template.replace("${PostDescription}", post.description);
						template = template.replace("${PostDate}", post.date);
						template = template.replace("${PostThumbnail}", post.thumbnail);
						template = template.replace("${PostContent}", post.content);
						template = template.replace("${PostFilename}", post.filename);
						for(i in 0...postLinkLists.length) {
							template = template.replace("${PostLinkList[" + i + "]}", postLinkLists[i].template);
						}
						// File.saveContent(filepath, template);
						save(filepath, template);
					}
				}
			} else if(fileObj.scope == "once") {
				fileObj.template = processIncludes(fileObj.template); // Resolve includes *before* doing any other replacements, so the included files will have their content replaced too
				for(i in 0...postLinkLists.length) {
					fileObj.template = fileObj.template.replace("${PostLinkList[" + i + "]}", postLinkLists[i].template);
				}
				var filepath = outputDir + "/" + fileObj.filename;
				// File.saveContent(filepath, fileObj.template);
				save(filepath, fileObj.template);
			} else {
				var filepath = outputDir + "/" + fileObj.filename;
				// File.saveContent(filepath, fileObj.template);
				save(filepath, fileObj.template);
			}
		}
	}

	static public function processIncludes(contentStr : String) : String {
		var i = contentStr.indexOf("${@");
		while(i != -1) {
			var j = contentStr.indexOf("}", i + 3); // Search for the first } after the ${@

			var includePath = contentStr.substring(i + 2, j); // Pick out the include path (including the '@', so I can just stick it in content())

			var replacement = content(includePath); // Use content() to read the file

			processIncludes(replacement); // Resolve includes in the replacement too

			var target = contentStr.substring(i, j + 1); // Get the whole ${@path} to use as a replacement target

			contentStr = contentStr.replace(target, replacement); // And... replace! This has the added bonus of doing it in the whole file

			i = contentStr.indexOf("${@", i + replacement.length); // Search from the position replaced. The replacement might need ${@'s that need resolving, might even start with one
		}
		return contentStr;
	}

	static public function content(contentStr : String) : String {
		// If first character is @, then the rest of the field will be the filename the content is at
		if(contentStr.charAt(0) == "@") {
			contentStr = File.getContent(FileSystem.absolutePath(contentStr.substring(1))); // Get the content of the file, filename starting at 2nd character
		}
		return contentStr;
	}

	static function save(path : String, content : String) {
		var containDir = path.substring(0, path.lastIndexOf("/"));
		FileSystem.createDirectory(containDir); // Create the containing directory if it does not exist
		File.saveContent(path, content);
	}
}
