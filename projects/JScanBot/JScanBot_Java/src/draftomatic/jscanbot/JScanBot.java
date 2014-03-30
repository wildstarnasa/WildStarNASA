package draftomatic.jscanbot;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.Writer;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

public class JScanBot implements ClipboardCallback {
	
	private static Log log = LogFactory.getLog(JScanBot.class);

	private ClipboardListener clipboardListener;
	
	private static final String DELIMITER = ":::";
	private static final String TOKEN = "JScanBot";
	
	private Map<String, Writer> writers = new HashMap<String, Writer>();

	public JScanBot() {
		this.clipboardListener = new ClipboardListener(this);
		this.clipboardListener.start();
	}
	
	
	@Override
	public void clipboardChanged(String content) {
		//log.info("Clipboard changed: " + content);
		
		if (!content.startsWith(TOKEN)) {
			log.info("Clipboard content not tokened; ignoring.");
			return;
		}
		//log.info("Got a message! Content: " + content);
		
		JScanBotMessage message = parseClipboardContent(content);
		if (message == null) {
			return;
		}
		//log.info(message.toString());
		
		switch (message.getType()) {
		case JScanBotMessage.OPEN_FILE:
			log.info("Opening file");
			this.openOutputFile(message.getPath(), false);
			break;
		case JScanBotMessage.OPEN_FILE_APPEND:
			log.info("Opening file for append");
			this.openOutputFile(message.getPath(), true);
			break;
		case JScanBotMessage.CLOSE_FILE:
			log.info("Closing file");
			this.closeOutputFile(message.getPath());
			break;
		case JScanBotMessage.WRITE_TO_FILE:
			log.info("Writing " + message.getMessage().length() + " characters to file: " + message.getPath());
			this.appendOutputFile(message.getPath(), message.getMessage());
			break;
		default:
		}
	}

	// Parse strings from WildStar
	private JScanBotMessage parseClipboardContent(String content) {
		String[] messageParts = content.split(DELIMITER);
		if (messageParts.length < 3) {
			log.error("Failed to parse tokened clipboard content: " + content);
			return null;
		}
		String messageType = messageParts[1];
		String path = messageParts[2];
		String message = null;
		if (messageParts.length > 3) {
			message = content.replaceFirst(TOKEN + DELIMITER + messageType + DELIMITER + path.replace("\\", "\\\\") + DELIMITER, "");
		}
		return new JScanBotMessage(path, messageType, message);
	}
	
	//
	// File routines below
	//
	private void openOutputFile(String path, boolean append) {
		Writer writer = writers.get(path);
		if (writer != null) {
			log.warn("Tried to open a file that's already open: " + path);
			return;
		}
		
		
		File file = new File(path);
		if (!file.exists() || !append) {
			try {
				this.createFullPathToFile(path);
				file.createNewFile();
			} catch (IOException e) {
				log.error("Failed to create output file: " + path, e);
				return;
			}
		}
		try {
			writer = new BufferedWriter(new FileWriter(new File(path), append));
			writers.put(path, writer);
		} catch (IOException e) {
			log.error("Failed to open output file " + path, e);
		}
	}
	
	private void closeOutputFile(String path) {
		Writer writer = writers.get(path);
		if (writer == null) {
			log.error("Tried to close a file that is not open: " + path);
			return;
		}
		try {
			writer.close();
		} catch (IOException e) {
			log.error("Failed to close output file: " + path, e);
		}
		writers.remove(path);
	}
	
	private void createDirectory(String path) {
		this.createFullPathToFile(path);
	}

	private void readFile(String path) {
		
	}

	private void appendOutputFile(String path, String content) {
		Writer writer = writers.get(path);
		if (writer != null) {
			try {
				writer.write(content);
				writer.flush();
			} catch (IOException e) {
				log.error("Failed to write content to file: " + path, e);
			}
		}
	}
	
	private String createFullPathToFile(String path) {
		File parentDir = new File(path);
		if (parentDir.isFile() || parentDir.getName().contains(".")) {
			parentDir = parentDir.getParentFile();
		}
		//log.info("full path to file: " + parentDir.getAbsolutePath());
		if (!parentDir.exists()) {
			if (!parentDir.mkdirs()) {
				log.error("Failed to create path: " + path, new Exception());
				return null;
			}
		}
		return path;
	}
	
}
