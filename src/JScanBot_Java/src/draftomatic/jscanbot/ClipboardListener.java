package draftomatic.jscanbot;

import java.awt.Toolkit;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.ClipboardOwner;
import java.awt.datatransfer.DataFlavor;
import java.awt.datatransfer.FlavorEvent;
import java.awt.datatransfer.FlavorListener;
import java.awt.datatransfer.Transferable;
import java.awt.datatransfer.UnsupportedFlavorException;
import java.io.IOException;
import java.io.Writer;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;


public class ClipboardListener extends Thread implements ClipboardOwner {

	private static Log log = LogFactory.getLog(ClipboardListener.class);
	
	private Clipboard sysClip = Toolkit.getDefaultToolkit().getSystemClipboard();  
	private ClipboardCallback callback;
	
	public ClipboardListener(ClipboardCallback callback) {
		this.callback = callback;
	}
	
	private void processNewContents(Transferable t) {  
		//log.info("Processing: " + t); 
		try {
			String content = (String)sysClip.getData(DataFlavor.stringFlavor);
			//log.info("New clipboard content: " + content);
			this.callback.clipboardChanged(content);
			
			//sysClip.set
		} catch (Exception e) {
			log.error("Exception getting clipboard content.", e);
			return;
		}
	}
	
	@Override
	public void run() {  
		Transferable trans = sysClip.getContents(this);  
		regainOwnership(trans);  
		while(true) {}  
	}
	@Override
	public void lostOwnership(Clipboard c, Transferable t) {
		Transferable contents = null;
		while (contents == null) {
			try {  
				Thread.sleep(30);  
			} catch(Exception e) {  
				log.error("Exception sleeping for clipboard: ", e);  
			}
			try {
				contents = sysClip.getContents(this);
			} catch (IllegalStateException e) {
				log.warn("Exception reading clipboard; trying again.");
			}
		}
		processNewContents(contents);  
		regainOwnership(contents); 
	}
	private void regainOwnership(Transferable t) {  
		sysClip.setContents(t, this);  
	}  
	
}
