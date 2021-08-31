using StringTools;
using sys.io.File;
using haxe.Json;
using String;
using sys.FileSystem;

typedef BlogSpec = {
	var postCollections : Array<PostCollectionJson>;
	var postLists : Array<PostList>;
	var files : Array<FileObj>;
}

typedef PostCollectionJson = {
	var postsJson : String;
}

typedef PostCollection = {
	var posts : Array<Post>;
}

typedef PostList = {
	var template : String;
	var postCollectionId : Int;
}

typedef FileObj = {
	var template : String;
	var scope : String;
	var filename : String;
}

typedef Post = {
	var title : String;
	var description : String;
	var date : String;
	var thumbnail : String;
	var content : String;
	var filename : String;
}

// TODO - Allow directories to be specified in blog.json

class Stagenx {
	static var outputDir : String = "";

	static public function main() : Void {
		// Take arguments
		if(Sys.args().length == 0) {
			Sys.stderr().writeString("[ERROR]: Blog json file path unspecified");
			// Sys.print("Usage: ") // TODO help
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
			Sys.setCwd(workingDir); // Set current working directory. Doesn't work in java
		}

		// Convert the relative path to absolute
		outputDir = FileSystem.absolutePath(outputDir);

		// Load the main json file
		var blogSpec : BlogSpec = Json.parse(File.getContent(FileSystem.absolutePath(blogJsonPath)));

		// Get all the posts
		var postCollections : Array<PostCollection> = [];
		for(postCollectionJson in blogSpec.postCollections) {
			var postCollectionArr : Array<Post> = Json.parse(content(postCollectionJson.postsJson));
			var postCollection : PostCollection = { posts: postCollectionArr };

			// Get the content for each post for each field. Yes it's silly to do it for each field but I canny be arsed to write what can and can't use @path, much less to make a decision on it
			for(post in postCollection.posts) {
				post.title = content(post.title);
				post.description = content(post.description);
				post.date = content(post.date);
				post.content = content(post.content);
				post.filename = content(post.filename);
			}

			// Append the post collection to the array
			postCollections.push(postCollection);
		}

		for(postList in blogSpec.postLists) {
			postList.template = content(postList.template); // Same old, use content() for @path

			// Now we need to copy the template for each post, making the necessary replacements along the way
			// So first we'll have a buffer to hold the replaced templates
			var postListTemplateBuf = new StringBuf();

			// Now we loop through all the posts that this post list is using and make the replacements and add the template to the buffer
			for(post in postCollections[postList.postCollectionId].posts) {
				var template = postList.template; // Make a copy of the template to do the replacements in
				template = template.replace("${PostTitle}", post.title);
				template = template.replace("${PostDescription}", post.description);
				template = template.replace("${PostDate}", post.date);
				template = template.replace("${PostThumbnail}", post.thumbnail);
				template = template.replace("${PostContent}", post.content);
				template = template.replace("${PostFilename}", post.filename);
				postListTemplateBuf.add(template);
			}
			postList.template = postListTemplateBuf.toString();
		}

		// Make output directory if it doesn't exist
		ensureDirExists(outputDir);

		// Now handle each file
		for(fileObj in blogSpec.files) {
			// *Sigh* do all the silly content replacement stuff
			fileObj.scope = content(fileObj.scope);
			fileObj.filename = content(fileObj.filename);

			// Now, fileObj.template *may* refer to a directory. In this case, we recursively read all the files in it
			// The files keep their path (relative to the target directory), and the scope is inherited
			if(fileObj.template.charAt(0) == '@') {
				var filepath = fileObj.template.substring(1);
				if(FileSystem.isDirectory(filepath)) {
					var dirContents = FileSystem.readDirectory(filepath);
					for(file in dirContents) {
						blogSpec.files.push({template: "@" + filepath + "/" + file, scope: fileObj.scope, filename: fileObj.filename + "/" + file});
					}
					continue;
				}
			}

			if(fileObj.scope.substr(0, 8) == "per-post") {
				// Get the index of the post collection used
				var postCollectionId : Int = Std.parseInt(fileObj.scope.substring(9)); // Get the string from index 9 to the end of the string. This should just be a number

				fileObj.template = content(fileObj.template);

				for(post in postCollections[postCollectionId].posts) {
					var filepath = outputDir + "/" + fileObj.filename.replace("${PostFilename}", post.filename);
					var template = fileObj.template;
					template = processIncludes(template); // Resolve includes *before* doing any other replacements, so the included files will have their content replaced too
					template = template.replace("${PostTitle}", post.title);
					template = template.replace("${PostDescription}", post.description);
					template = template.replace("${PostDate}", post.date);
					template = template.replace("${PostThumbnail}", post.thumbnail);
					template = template.replace("${PostContent}", post.content);
					template = template.replace("${PostFilename}", post.filename);
					for(i in 0...blogSpec.postLists.length) {
						template = template.replace("${PostList[" + i + "]}", blogSpec.postLists[i].template);
					}
					save(filepath, template);
				}
			} else if(fileObj.scope == "once") {
				fileObj.template = content(fileObj.template); // Get the content
				fileObj.template = processIncludes(fileObj.template); // Resolve includes *before* doing any other replacements, so the included files will have their content replaced too
				for(i in 0...blogSpec.postLists.length) {
					fileObj.template = fileObj.template.replace("${PostList[" + i + "]}", blogSpec.postLists[i].template);
				}
				var filepath = outputDir + "/" + fileObj.filename;
				save(filepath, fileObj.template);
			} else {
				// No point getting the content of the file if we're not doing replacements, therefore simply don't. Copy the file instead
				var filepath = outputDir + "/" + fileObj.filename;

				// Make sure the target directory exists
				var containDir = filepath.substring(0, filepath.lastIndexOf("/"));
				ensureDirExists(containDir); // Create the containing directory if it does not exist

				// Now either copy the file (if @) or write the content
				if(fileObj.template.charAt(0) == '@') {
					File.copy(fileObj.template.substring(1), filepath);
				} else {
					save(filepath, fileObj.template.substring(1));
				}
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

	static public function save(path : String, content : String) : Void {
		var containDir = path.substring(0, path.lastIndexOf("/"));
		ensureDirExists(containDir);

		File.saveContent(path, content);
	}

	static public function ensureDirExists(path : String) : Void {
		// Make output directory if it doesn't exist
		if(!FileSystem.exists(path)) {
			FileSystem.createDirectory(path);
		} else if(!FileSystem.isDirectory(path)) {
			Sys.stderr().writeString("[ERROR]: Cannot create directory " + path + " - Non-directory file with that path already exists. Exiting");
			Sys.exit(1);
		}
	}
}
