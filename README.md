# Stagenx

Simple static blog generator written in haxe. Really just automated copy-pasting

## Running

You need haxe (I used haxe 4.2.2, may work on earlier versions though).

```bash
haxe --run Stagenx.hx <blog.json path> [output directory] [working directory]
```

The output directory and working directory are optional arguments. Output directory defaults to "output" in the current working directory. Both blog.json and output directory are affected by setting the working directory.

For example:

```bash
haxe --run Stagenx.hx blog.json output ..
```

The above will read blog.json from the parent directory (../blog.json) and put the output in ../output (Creating it if it doesn't exist).

The working directory also affects files references (@filepath) in blog.json and other json files. If blog.json references template-1.html and the working directory is /home/www-data, it will read /home/www-data/template-1.html

(Tip: Use the Makefile so you can just type `make` instead of `haxe --run Stagenx.hx <blog.json path> [output directory] [working directory]`)

## blog.json

(The filename doesn't actually have to be blog.json. Same applies to all other filenames mentioned)

Structure:

```json
{
	"postLinkLists": [
		{
			"template": "@post-link-template.html",
			"postsJson": "@posts.json"
		}
	],
	"files": [
		{
			"template": "@template.html",
			"scope": "scope",
			"filename": "filename"
		}
	]
}
```

You can also specify without the @ to use content embedded within the JSON: `"template": "<h1>${PostTitle}</h1>"`

### postLinkLists

On a page that lists all the posts, you have links to each post - These typically are a little more than just an `<a>` tag, but with this you can have it however you want

This JSON element is a list of PostLinkList objects, which have:
- template - This is the template used for each post link
- postsJson - This is a file containing a list of posts. See [posts.json](#postsjson) for it's format

In the template, the following replacements are made:
- ${PostTitle} - Replaced with the post "title" from JSON
- ${PostDescription} - Replaced with the post "description" from JSON
- ${PostDate} - Replaced with the post "date" from JSON
- ${PostThumbnail} - Replaced with the post "thumbnail" from JSON
- ${PostContent} - Replaced with the post "content" from JSON

The post link list will be generated by copying the template for each post in postsJson and replacing the above for each post

### files

This is an array of File objects, each having:
- template - This is the actual file
- scope - This is either "per-post", "once", or "no-replace", and it defines how many times the file is copied and what replacements are made
- filename - This is the name of the file as outputted

#### scope

"per-post"
- The file is copied once for each post, and so has access to a bunch of post-specific replacements:
	- ${PostTitle} - Replaced with the post "title" from JSON
	- ${PostDescription} - Replaced with the post "description" from JSON
	- ${PostDate} - Replaced with the post "date" from JSON
	- ${PostThumbnail} - Replaced with the post "thumbnail" from JSON
	- ${PostContent} - Replaced with the post "content" from JSON
	- ${PostFilename} - Replaced with the post "filename" from JSON
- As well as some non-post-specific ones:
	- ${PostLinkList[N]} - Replaced with index N in the postLinkLists JSON array
- Also, you can use ${PostTitle} and ${PostFilename} in the filename to make it unique between files. The generator will simply overwrite the files in the case of identical filenames

"once"
- The file is copied once, and so has access to only non-post-specific replacements:
	- ${PostLinkList[N]} - Replaced with index N in the postLinkLists JSON array

"no-replace"
- The file is copied once, and the generator does not attempt to replace anything in the file. Suitable for binary files and large files

## post-link-template.html

On a page that lists all the posts, you have links to each post - These typically are a little more than just an `<a>` tag, but with this you can have it however you want. They also don't have to be used as links. None of these files have to be used as intended in fact

Replacements
- ${PostTitle} - Replaced with the post "title" from JSON
- ${PostDescription} - Replaced with the post "description" from JSON
- ${PostDate} - Replaced with the post "date" from JSON
- ${PostThumbnail} - Replaced with the post "thumbnail" from JSON
- ${PostContent} - Replaced with the post "content" from JSON

## posts.json

List of Post objects

Structure:

```json
[
	{
		"title": "Post Title",
		"description": "Post Description",
		"date": "dd MMMM yyyy - hh:mm ap",
		"thumbnail": "default.png",
		"content": "@post-content.html"
	}
]
```

The date can be in any format, but the one I like to use is 'dd MMMM yyyy - hh:mm ap' as defined in the [Qt time format](https://doc.qt.io/qt-5/qml-qtqml-qt.html#formatDateTime-method)
