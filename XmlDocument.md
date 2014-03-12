# XmlDocument

> XmlDocument = Apollo.GetPackage("Drafto:Lib:XmlDocument-1.0").tPackage 

**XmlDocument** is an XML manipulation library for Apollo. Its main purpose is to build Form documents purely from Lua, which can then be loaded as Windows in your Addon. This allows us to create arbitrary Windows on-the-fly, at run-time, without touching the file system. However, XmlDocument can also be used to create, modify, and serialize arbitrary XML documents. 

XmlDocument can be thought of as a wrapper for Apollo's **XmlDoc**, but with massively extended functionality and a legitimate [DOM](http://en.wikipedia.org/wiki/Document_Object_Model) API.


***
## Quick Links

1. <a href="#draftotag1">Relationship to XmlDoc</a>
1. <a href="#draftotag2">XmlDocument and XmlNode</a>
1. <a href="#draftotag3">Create a Window</a>
1. <a href="#draftotag4">Create an XML String</a>
1. <a href="#draftotag5">Traverse a Document's Nodes</a>
1. <a href="#draftotag6">API Reference</a>


<div id="draftotag1"></div>
***
## Relationship to XmlDoc

Chances are you've used XmlDoc already, because Houston will generate a call to one of its methods when you create a new Addon:

    self.xmlDoc = XmlDoc.CreateFromFile("MyAddon.xml")

But what is XmlDoc? Very simply, it's Apollo's in-memory representation of an XML document. Here, the file "MyAddon.xml" is parsed and read into some C++ object, which is given to us as userdata. Take a look at one if you like, however you'll find its methods a bit cryptic. Many of them, such as `AddLine()`, are meant for creating MLWindow markup rather than full-blown Forms. But XmlDocs *can* create Forms, so where are the  immediately wanting methods like `GetChildren()` and `FindChild()`, similar to 

With a vanilla XmlDoc, the only solution is to convert the XmlDoc to a table using the `ToTable()` method (or start from a new table), do your thing, then convert it back into an XmlDoc using `XmlDoc.CreateFromTable()`. I won't dive into what this table looks like, because with XmlDocument you don't ever have to see it.


<div id="draftotag2"></div>
***
## Create a Window




<div id="draftotag3"></div>
***
## Create an XML String




<div id="draftotag5"></div>
***
## Traverse a Document's Nodes

Assuming we have an XmlNode, often the root node, we can 


<div id="draftotag6"></div>
***
## API Reference

#### XmlDocument (The Package)

This is the table returned by `Apollo.GetPackage()`. It contains the factory methods for new documents, as well as wrapped versions of XmlDoc's factory methods. The returned XmlDocument object is described in the next section.

-  **XmlDocument.New()**

   Returns a new XmlDocument. This document's root will be nil, so be sure to create a root node and call `SetRoot()`.

-  **XmlDocument.NewForm()**

   Returns a new Form XmlDocument. This is a special type of XmlDocument that has extra methods specific to Form XML, such as `LoadForm()`. It also comes with a root node, which is a `<Forms>` element with no attributes.

-  **XmlDocument.CreateFromFile(strPath)**

   Similar to `XmlDoc.CreateFromFile()`, this parses the XML file at `strPath` and returns it as a new XmlDocument. 

-  **XmlDocument.CreateFromTable(tXml)**

   Returns a new XmlDocument built from `tXml`. `tXml` should be a table in the same format as the one returned by `XmlDoc:ToTable()`, or the one given to `XmlDoc.CreateFromTable()`.


#### XmlDocument (The Object)

The above factory methods return an object with the following API:

-  **XmlDocument:GetRoot()**

   Returns the root XmlNode for this document.

-  **XmlDocument:SetRoot(tNode)**

   Sets the root node of this document to XmlNode `tNode`.

-  **XmlDocument:NewNode(strTag, tAttributes)**

   Returns a new XmlNode for this document. `strTag` will be the tag name, and `tAttributes` is a table of string key/value attribute pairs. Note that this method doesn't actually add the new node to the document; you must also append it to another node using `XmlNode:AddChild()`.

-  **XmlDocument:ToXmlDoc()**

   Returns an XmlDoc equivalent to this XmlDocument.

-  **XmlDocument:ToTable()**

   Returns a table equivalent to this XmlDocument that can be passed to `XmlDoc.CreateFromTable()`.

-  **XmlDocument:Serialize()**

   Returns an XML string of this entire document, with indenting.

-  **XmlDocument:NewFormNode(strName, tAttributes)**
   
   \* *Form documents only*

   Creates a new Form element for this document with Name `strName`. Note that this method doesn't actually add the new node to the document; you must also append it to another node using `XmlNode:AddChild()`.

-  **XmlDocument:NewControlNode()**
   
   \* *Form documents only*

   ReNote that this method doesn't actually add the new node to the document; you must also append it to another node using `XmlNode:AddChild()`.

-  **XmlDocument:LoadForm(strName, wndParent, tHandler)**
   
   \* *Form documents only*

   Loads the Form with Name `strName` as a Window. This is equivalent to `Apollo.LoadForm()`. `wndParent` is the parent Window, and can be nil for a top-level Window. `tHandler` is the table used for event callbacks. There is currently a bug in Apollo where if tHandler is nil, events registered after loading the Window will fail to fire. So it's a good idea to always pass `self` as the 3rd argument.


#### XmlNode

An XmlNode is an object representing a single XML element, or node. `XmlDocument:NewNode()` returns an XmlNode.

-  **XmlNode:GetDocument()**

   Returns the owner XmlDocument of this node.

-  **XmlNode:SetDocument(tDoc)**

   Sets the owner XmlDocument of this node. This relationship isn't enforced at all; it's simply for convenience.

-  **XmlNode:GetChildren()**

   Returns an array of XmlNode children for this node.

-  **XmlNode:AddChild(tNode)**

   Appends `tNode` to this node, and updates its owner document.

-  **XmlNode:RemoveChild(nId)**

   Removes and returns the child node at index `nId`.

-  **XmlNode:Attribute(strName, value)**

   Returns the value of attribute `strName`. Alternatively, if `value` is given, sets attribute `strName` to `value`.

   For Form documents, attributes should be identical to the Form XML files. There are also two special attributes, `AnchorPoints` and `AnchorOffsets`, which can be given as a `{left,top,right,bottom}` array form we've seen in other Apollo methods.

-  **XmlNode:Text(strText)**

   Returns the inner text of this node. Alternatively, if `strText` is given, sets the inner text to `strText`.

-  **XmlNode:EachChild(fn)**

   Traverses each child of this node recursively, repeatedly calling `fn` with the current node as an argument.

-  **XmlNode:FindChild(fn)**

   Traverses each child of this node recursively, repeatedly calling `fn` with the current node as an argument. If `fn` returns true, the current node is returned. Otherwise traversal continues.

-  **XmlNode:FindChildByName(strName)**

   Returns the first node with a Name attribute equal to `strName`.

-  **XmlNode:ToTable()**

   Returns a table equivalent to this XmlNode (and all its children) that can be passed to `XmlDoc.CreateFromTable()`.

-  **XmlNode:Serialize()**

   Returns an XML string of this node (and all its children), with indenting.
