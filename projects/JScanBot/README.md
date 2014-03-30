# JScanBot

> `local JScanBot = Apollo.GetAddon("JScanBot")`

This tool will let you write text to any file you want, at run-time, without reloading the UI. It's named JScanBot because I maybe possibly sort of stole the entire idea from Packetdancer, who has her own similar tool called ScanBot. Mine uses Java, so it's JScanBot!

There is one big, giant caveat to this technique. You have to be running an external program in conjunction with an Addon to make it happen. Why? Because data is exported from WildStar using `Window:CopyTextToClipboard()`. The clipboard is an OS-level construct, so as long as Apollo lets us set its content, we can communicate with the outside world (at least one-way). We can't read from the filesystem, so this is more of an "export" tool than a "save" tool.


### JScanBot: The Addon

Install the Addon like any other. It works like a library, but exists as an Addon so that it has a Form to use for clipboard writing. To connect it to your code, use Apollo's Package system to get "JScanBot".

Here's the API:

-  **JScanBot:OpenFile(strPath, bAppend)**

   Opens the file at strPath (always use absolute paths!) for writing. The file (and any parent folders) will be created if they don't exist. If bAppend is true, the file will not be wiped on opening, and text written to the file will be appended. A handle to the file will be kept open by the Java application until CloseFile() is called on this path.

-  **JScanBot:WriteToFile(strPath, strText)**

   Writes strText to the file at strPath. If the file is not open, nothing will happen. Large strings are buffered and written to the Java application on a timer, so as to not overwhelm Apollo or the clipboard. So if you print a huge string, it may take a few seconds for it to appear in the file.

-  **JScanBot:CloseFile(strPath)**

   Closes the file at strPath. Remember to call this!

-  **JScanBot:IsFileOpen(strPath)**

   Returns a boolean indicating whether the file at strPath is open. Bear in mind, the Lua Addon actually doesn't know whether the file is open, nor does it know whether writes are successful, etc. It's a one-way street. This just keeps track of previous calls for you on the Lua side.

-  **JScanBot:GetOpenFiles()**

   Returns an array of open file paths. If other Addons are using JScanBot, their files will show up here too.

I'm probably going to redo this API to something like `JScanBot:GetWriter(strPath, bAppend)` which would return a Writer object that can write to the given file. For now you have to keep track of the paths you're writing to and pass them to all the methods, which is a little clumsy.


### JScanBot: The Java Program

For any of the above Addon methods to work, you need to be running the Java program outside of WildStar. It's running on Java 7, so go update if you're unsure. If you have trouble running this program, I suggest just installing the JDK. This is the beefed-up developer version of Java that I find has a better chance of simply working, but obviously it's a bigger download. Otherwise you can ask me for help but there's a lot of information about Java around the internet, because it's quite popular (if you hadn't noticed). Here are some issues I would anticipate:

- Java is not installed, or is out-of-date. Update your Java!
- Your %PATH% environment variable does not include java.exe. 
- Permissions. Make sure you're running JScanBot.bat with sufficient permissions to run and write to the file you want.

Anyway, download the .zip file and extract it somewhere. It's quite compact; just double-click on RunJScanBot.bat (a Windows batch file), which should open a terminal window displaying output from JScanBot. Output is also logged to a file in the /log folder. Be sure to watch the log file or the terminal window, because a lot of things can go wrong. If you see exceptions logged, don't panic! Some exceptions are okay. Check the output file to see what was written. To stop, just close the terminal window, but make sure the Addon isn't in the middle of writing! If that happens, the file streams will close abruptly and you will almost certainly lose data.


### Example

    local JScanBot = Apollo.GetAddon("JScanBot")
    
    local strPath = "C:\\temp\\test.txt"
	JScanBot:OpenFile(strPath)
	JScanBot:WriteToFile(strPath, "Hello World!")
	JScanBot:CloseFile(strPath)