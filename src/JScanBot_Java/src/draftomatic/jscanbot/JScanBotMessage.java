package draftomatic.jscanbot;

public class JScanBotMessage {
	public static final String OPEN_FILE = "OpenFile";
	public static final String OPEN_FILE_APPEND = "OpenFileAppend";
	public static final String CLOSE_FILE = "CloseFile";
	public static final String WRITE_TO_FILE = "WriteToFile";
	
	private String path;
	private String type;
	private String message;
	
	public JScanBotMessage(String path, String type, String message) {
		this.path = path;
		this.type = type;
		this.message = message;
	}
	
	public String getPath() {
		return path;
	}
	public void setPath(String path) {
		this.path = path;
	}
	public String getType() {
		return type;
	}
	public void setType(String type) {
		this.type = type;
	}
	public String getMessage() {
		return message;
	}
	public void setMessage(String message) {
		this.message = message;
	}

	@Override
	public String toString() {
		return "JScanBotMessage [path=" + path + ", type=" + type
				+ ", message=" + message + "]";
	}
}

