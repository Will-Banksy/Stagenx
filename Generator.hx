using StringTools;
using sys.io.File;
using haxe.Json;
using String;

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

class Generator {
	static var outputDir : String = "output";

	static public function main() {
		// Load the main json file
		var blogSpec : BlogSpecJson = Json.parse(File.getContent("parts/blog.json"));

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

		// Now handle each file
		for(fileObj in blogSpec.files) {
			fileObj.template = content(fileObj.template);
			if(fileObj.scope == "per-post") {
				for(postLinkList in postLinkLists) {
					for(post in postLinkList.posts) {
						var filepath = outputDir + "/" + fileObj.filename.replace("${PostFilename}", post.filename);
						var template = fileObj.template;
						template = template.replace("${PostTitle}", post.title);
						template = template.replace("${PostDescription}", post.description);
						template = template.replace("${PostDate}", post.date);
						template = template.replace("${PostThumbnail}", post.thumbnail);
						template = template.replace("${PostContent}", post.content);
						template = template.replace("${PostFilename}", post.filename);
						for(i in 0...postLinkLists.length) {
							template = template.replace("${PostLinkList[" + i + "]}", postLinkLists[i].template);
						}
						File.saveContent(filepath, template);
					}
				}
			} else if(fileObj.scope == "once") {
				for(i in 0...postLinkLists.length) {
					fileObj.template = fileObj.template.replace("${PostLinkList[" + i + "]}", postLinkLists[i].template);
				}
				var filepath = outputDir + "/" + fileObj.filename;
				File.saveContent(filepath, fileObj.template);
			} else {
				var filepath = outputDir + "/" + fileObj.filename;
				File.saveContent(filepath, fileObj.template);
			}
		}
		// TODO ... Unless it's done?
	}

	static public function content(contentStr : String) : String {
		// If first character is @, then the rest of the field will be the filename the content is at
		if(contentStr.charAt(0) == "@") {
			contentStr = File.getContent(contentStr.substring(1)); // Get the content of the file, filename starting at 2nd character
		}
		return contentStr;
	}
}
