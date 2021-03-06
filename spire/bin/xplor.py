#!/usr/bin/env python
#
# SOURCE:   xplor.py 
#
# PURPOSE:  Simple browser for SPIDER files, 
#           based on idlelib.TreeWidget
#
# Spider Python Library
# Copyright (C) 2006-2018  Health Research Inc., Menands, NY
# Email:    spider@health.ny.gov

import os, string, sys
from   commands import getoutput
import webbrowser

from   Tkinter import *
from   tkFileDialog   import askdirectory
from   tkMessageBox   import askyesno
from   PIL            import Image
from   PIL            import ImageTk
import Pmw

from   idlelib        import ZoomHeight
from   Spider         import Spiderutils

icondict = {}

MAXDIRSIZE = 5000
SHOWHIDDEN = 0

##################################################################
# icons

def listicons(root):
    global icondict
    """Utility to display the available icons."""
    
    win = Toplevel(root)
    win.title('icons')

    names = icondict.keys()
    names.sort()
    N = len(names)
    
    row = column = 0
    for name in names:
        image = icondict[name]

        #btn = Button(win, image=image) #, bd=1, relief="raised")
        #btn.grid(row=row, column=column)
        lbl = Label(win, image=image, bd=1, relief="raised")
        lbl.grid(row=row, column=column)
        label = Label(win, text=name)
        label.grid(row=row+1, column=column)
        column = column + 1
        if column >= N/2:
            row = row+2
            column = 0
            
def makeIcons():
    icons = {}
    iconlist = ['updir','binary', 'docfile', 'docfiles', 'folder', 'image',
                'minusnode', 'openfolder', 'plusnode', 'procfile', 'python',
                'spider', 'spider1', 'text', 'toobig', 'unknown', 'vol1', 'vol2', 'volume']

    updir = PhotoImage(format='gif',data=
                 'R0lGODlhGQATAIAAAAAAAP///yH5BAEAAAEALAAAAAAZABMAAAI0jI+py+0P'
                +'DZg0JqCwDTpbCoZidXQbh5imo5ZT1HIgFEtfisO5rZfp+NqhTrziSQVMkoiM'
                +'AgA7')
        
    binary = PhotoImage(format='gif',data=
                 'R0lGODlhDAAMAKUAAAAAAAMDAwEBAQUFBQ4ODhAQEAwMDAcHB0FBQRISEgQE'
                +'BBUVFf///xwcHD8/PzAwMCsrK/X19fn5+SkpKTIyMk9PTwsLCxgYGC8vL/z8'
                +'/E5OTggICC4uLvDw8AYGBjk5OVBQUAkJCRkZGRoaGuLi4uDg4P39/TMzM8nJ'
                +'yd7e3jExMQoKCv//////////////////////////////////////////////'
                +'/////////////////////////////////yH5BAEKAD8ALAAAAAAMAAwAAAZn'
                +'QIBwSAwIiANCwRA4IBJCxYJBZTQcjAcgAKFGJIwJlQIwVKkVy4WBARSoGYZm'
                +'I2RwAARGR+4Z2gEDHwwgIUNrbQAeIhZDIwwkZAcADBdCayUmJwEAKClnDHEn'
                +'AgkqFBgcHBgUJycrQQA7')

    docfile = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAKEAAAAAAKjc/////////yH5BAEKAAMALAAAAAAOAA8AAAIq'
                +'nI+ZwK3DggxAAQEmXQLrejTRBBqZRiInuoWsVEJva87xit62uofibygAADs=')

    docfiles = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAKEAAAAAAKjc/////////yH5BAEKAAMALAAAAAAOAA8AAAIv'
                +'nI+ZwK3DggxAAQEmXQLrejTRBBqZRiInuoXSmpUQSb3qK7Ymfco9f2PpIKKi'
                +'oQAAOw==')

    folder = PhotoImage(format='gif',data=
                 'R0lGODlhDwANAKL/AP//z///kP/PkO/v78/PYJCQAAAAAMDAwCH5BAEAAAcA'
                +'LAAAAAAPAA0AQAM9eFfMplAVEKoVAQtipv0XdxhkaZoFoa5E0ywUWGncpGW4'
                +'oIvFAMSFRwT2KxoptRjollzmAs3Zc9dhWVmGBAA7')

    image = PhotoImage(format='gif',data=
                 'R0lGODlhDgASALMAAAAIAAoCCAQMBgcMEBESDB4UDR0iETEuGUs8GVxPLmpr'
                +'PYR5SJqNTqefa8+uZd3RiCH5BAEAAAEALAAAAAAOABIAAASQUKlFGWsYvzeX'
                +'bcyCOc5WYUyCFMpmZs3yOGvjJh6oOCmRNKUDAqHAkRaBg+dhODgLCUtiYEhM'
                +'CIbmobBQHAIGiQJ8SHwLiETBJyE4DQQuKZG9CuGtmWq4aCIMBSV6f0kGCAcC'
                +'hhMJWAQBBG4FA5NwAlQHA1gHBAOWnQNgnJCTpJ+lpJUCqp6Tok1dCKOkBBEA'
                +'ADs=')
    
    minusnode = PhotoImage(format='gif',data=
                 'R0lGODlhCwALAJEAAP///39/fwAAAMDAwCH5BAkAAAMALAAAAAALAAsAAAgy'
                +'AAcIHEhQYICDCBEaBMCwIYAACx0yhDgggMSJCwVo1PgwokSKFi+CvNixYsKE'
                +'BVMOCAgA')

    openfolder = PhotoImage(format='gif',data=
                 'R0lGODlhEAANAKL/AP//kP/PkPDw8M/PYJCQAAAAAMDAwAAAACH5BAEAAAYA'
                +'LAAAAAAQAA0AQANCaErM+pAIQGkAIZCyjawgOBRPYZ7o6U2g0DRriGHjMC7C'
                +'pWfBsJErgdAFibBCQ8HoxWwMAMvjbFa7fWa7HgfYbJoSADs=')

    plusnode = PhotoImage(format='gif',data=
                 'R0lGODlhCwALAJH/AP///39/fwAAAMDAwCH5BAEAAAMALAAAAAALAAsAQAIg'
                +'nI8WwA2hmmhwLMfqBTOnrwTiKEZM90TCuqaWRIXkOBQAOw==')

    procfile = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAKEAAAAAAAD/AP///////yH5BAEKAAMALAAAAAAOAA8AAAIq'
                +'nI+ZwK3DggxAAQEmXQLrejTRBBqZRiInuoWsVEJva87xit62uofibygAADs=')

    python = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAKL/AAAAAAD/AP8AAMDAwP//AICAAAAA/wAAACH5BAEAAAMA'
                +'LAAAAAAOAA8AQANCOAqs/kAIBkIBi5XL931DZXUbthiAcZmOGLwBUILMO4ff'
                +'Au8sfoMhAEEoyy08nhGrNolVjKGJaCYzTVea3BUZGyQAADs=')

    spider = PhotoImage(format='gif',data=
                 'R0lGODlhDwAPAKEAAFhYWKjc/wAAAP///yH5BAEKAAMALAAAAAAPAA8AAAIy'
                +'HI6JFu3vjhOQNtnsjOBpHUhfMGICdaIWlqUg24JhF7scaaHt7G23T3rAIEKD'
                +'4ggYFAAAOw==')

    spider1 = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAIAAAAAAAP///yH5BAEKAAEALAAAAAAOAA8AAAIijI95sGqM'
                +'YJLP0UClbhiC/1zfCDrdtZBkmmoip7zxZG5IAQA7')

    text = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAKEAAAAAAP///////////yH5BAEKAAIALAAAAAAOAA8AAAIp'
                +'lI+ZwK3CggxAATrpknfW00Qe0mUcaY5geq7sZ5QmDLGam9Jypoe+UQAAOw==')

    toobig = PhotoImage(format='gif',data=
                 'R0lGODlhCwALAKEAAH9/f/////8AAP///yH5BAEKAAMALAAAAAALAAsAAAIf'
                +'nI8Gy6wBoRDgxRnqAFdAzQXY94zkZp6AF6lNk8RDAQA7')

    unknown = PhotoImage(format='gif',data=
                 'R0lGODlhDAAMAKEAAP///wAAAP///////yH5BAEKAAIALAAAAAAMAAwAAAIT'
                +'hI8JwaGL3DtyQltfVttif4FJAQA7')

    vol1 = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAMIAAAAAAP///6CgoNzc3P///////////////yH5BAEKAAQA'
                +'LAAAAAAOAA8AAAMzSLrc/g3IKWO4uC6AswBbdwHCp1BUaRLA4L5kCbIvrM5t'
                +'PcRrXsczmo4UFP6KLJQGwkwAADs=')

    vol2 = PhotoImage(format='gif',data=
                 'R0lGODlhDgAPAKEAAAAAAICAgP///////yH5BAEKAAMALAAAAAAOAA8AAAIy'
                +'nI+pm+DvWhCUxgPErBlgugmZaEAQV1bbSA7sirpqEAB0nWqc9YViW/KJPAjT'
                +'g4E0FAAAOw==')

    volume = PhotoImage(format='gif',data=
                 'R0lGODlhDwAPAMIAAAAAAKjc/1io/8DA/6CgoP///////////yH5BAEKAAcA'
                +'LAAAAAAPAA8AAANBeHrQ/mCBQGttaloLRNQb1XlQKZzNoK7rSLYD0J6vbMcx'
                +'ncaP6u4DAoAwQ8l4Dp/uxsx5GLBjLgJlsTCZ0mNxSAAAOw==')

    for icon in iconlist:
        icons[icon] = eval(icon)

    return icons
    
##################################################################
#

class TreeNode:

    def __init__(self, canvas, parent, item):
        self.canvas = canvas
        self.parent = parent
        self.item = item
        self.state = 'collapsed'
        self.selected = False
        self.children = []
        self.x = self.y = None
        self.icondict = canvas.icondict
        self.iconimages = {} # cache of PhotoImage instances for icons

    def destroy(self):
        for c in self.children[:]:
            self.children.remove(c)
            c.destroy()
        self.parent = None

    def geticonimage(self, name):
        if self.icondict.has_key(name):
            image = self.icondict[name]
            return image

    def select(self, event=None):
        if self.selected:
            return
        self.deselectall()
        self.selected = True
        self.canvas.delete(self.image_id)
        self.drawicon()
        self.drawtext()

    def deselect(self, event=None):
        if not self.selected:
            return
        self.selected = False
        self.canvas.delete(self.image_id)
        self.drawicon()
        self.drawtext()

    def deselectall(self):
        if self.parent:
            self.parent.deselectall()
        else:
            self.deselecttree()

    def deselecttree(self):
        if self.selected:
            self.deselect()
        for child in self.children:
            child.deselecttree()

    def flip(self, event=None):
        #if self.state == 'expanded':
            #self.collapse()
        #else:
            #self.expand()
        self.item.OnDoubleClick()
        return "break"

    def expand(self, event=None):
        if not self.item._IsExpandable():
            return
        if self.state != 'expanded':
            self.state = 'expanded'
            self.update()
            self.view()

    def collapse(self, event=None):
        if self.state != 'collapsed':
            self.state = 'collapsed'
            self.update()

    def view(self):
        top = self.y - 2
        bottom = self.lastvisiblechild().y + 17
        height = bottom - top
        visible_top = self.canvas.canvasy(0)
        visible_height = self.canvas.winfo_height()
        visible_bottom = self.canvas.canvasy(visible_height)
        if visible_top <= top and bottom <= visible_bottom:
            return
        x0, y0, x1, y1 = self.canvas._getints(self.canvas['scrollregion'])
        if top >= visible_top and height <= visible_height:
            fraction = top + height - visible_height
        else:
            fraction = top
        fraction = float(fraction) / y1
        self.canvas.yview_moveto(fraction)

    def lastvisiblechild(self):
        if self.children and self.state == 'expanded':
            return self.children[-1].lastvisiblechild()
        else:
            return self

    def update(self):
        if self.parent:
            self.parent.update()
        else:
            oldcursor = self.canvas['cursor']
            self.canvas['cursor'] = "watch"
            self.canvas.update()
            self.canvas.delete(ALL)     # XXX could be more subtle
            self.draw(7, 2)
            x0, y0, x1, y1 = self.canvas.bbox(ALL)
            self.canvas.configure(scrollregion=(0, 0, x1, y1))
            self.canvas['cursor'] = oldcursor

    def draw(self, x, y):
        # XXX This hard-codes too many geometry constants!
        self.x, self.y = x, y
        self.drawicon()
        self.drawtext()
        if self.state != 'expanded':
            return y+17
        # draw children
        if not self.children:
            sublist = self.item._GetSubList()
            if not sublist:
                # _IsExpandable() was mistaken; that's allowed
                return y+17
            for item in sublist:
                child = self.__class__(self.canvas, self, item)
                self.children.append(child)
        cx = x+20
        cy = y+17
        cylast = 0
        for child in self.children:
            cylast = cy
            self.canvas.create_line(x+9, cy+7, cx, cy+7, fill="gray50")
            cy = child.draw(cx, cy)
            if child.item._IsExpandable():
                ####
                if os.path.getsize(child.item.path) > MAXDIRSIZE:
                    iconname = "toobig"
                    image = self.geticonimage(iconname)
                    id = self.canvas.create_image(x+9, cylast+7, image=image)
                else:
                    if child.state == 'expanded':
                        iconname = "minusnode"
                        callback = child.collapse
                    else:
                        iconname = "plusnode"
                        callback = child.expand
                    image = self.geticonimage(iconname)
                    id = self.canvas.create_image(x+9, cylast+7, image=image)
                    # XXX This leaks bindings until canvas is deleted:
                    self.canvas.tag_bind(id, "<1>", callback)
                    self.canvas.tag_bind(id, "<Double-1>", lambda x: None)
                    
        id = self.canvas.create_line(x+9, y+10, x+9, cylast+7,
            ##stipple="gray50",     # XXX Seems broken in Tk 8.0.x
            fill="gray50")
        self.canvas.tag_lower(id) # XXX .lower(id) before Python 1.5.2
        return cy

    def drawicon(self):
        if self.selected:
            imagename = (self.item.GetSelectedIconName() or
                         self.item.GetIconName() or
                         "openfolder")
        else:
            imagename = self.item.GetIconName() or "folder"
        image = self.geticonimage(imagename)
        id = self.canvas.create_image(self.x, self.y, anchor="nw", image=image)
        self.image_id = id
        self.canvas.tag_bind(id, "<1>", self.select)
        self.canvas.tag_bind(id, "<Double-1>", self.flip)

    def drawtext(self):
        textx = self.x+20-1
        texty = self.y-1
        labeltext = self.item.GetLabelText()
        if labeltext:
            id = self.canvas.create_text(textx, texty, anchor="nw",
                                         text=labeltext)
            #self.canvas.tag_bind(id, "<1>", self.select)
            #self.canvas.tag_bind(id, "<Double-1>", self.flip)
            x0, y0, x1, y1 = self.canvas.bbox(id)
            textx = max(x1, 200) + 10
        text = self.item.GetText() or "<no text>"
        try:
            self.entry
        except AttributeError:
            pass
        else:
            self.edit_finish()
        try:
            label = self.label
        except AttributeError:
            # padding carefully selected (on Windows) to match Entry widget:
            self.label = Label(self.canvas, text=text, bd=0, padx=2, pady=2)
        if self.selected:
            self.label.configure(fg="white", bg="darkblue")
        else:
            self.label.configure(fg="black", bg="white")
        id = self.canvas.create_window(textx, texty,
                                       anchor="nw", window=self.label)
        self.label.bind("<1>", self.select_or_edit)
        self.label.bind("<Double-1>", self.flip)
        self.text_id = id

    def select_or_edit(self, event=None):
        if self.selected and self.item.IsEditable():
            self.edit(event)
        else:
            self.select(event)

    def edit(self, event=None):
        self.entry = Entry(self.label, bd=0, highlightthickness=1, width=0)
        self.entry.insert(0, self.label['text'])
        self.entry.selection_range(0, END)
        self.entry.pack(ipadx=5)
        self.entry.focus_set()
        self.entry.bind("<Return>", self.edit_finish)
        self.entry.bind("<Escape>", self.edit_cancel)

    def edit_finish(self, event=None):
        try:
            entry = self.entry
            del self.entry
        except AttributeError:
            return
        text = entry.get()
        entry.destroy()
        if text and text != self.item.GetText():
            self.item.SetText(text)
        text = self.item.GetText()
        self.label['text'] = text
        self.drawtext()
        self.canvas.focus_set()

    def edit_cancel(self, event=None):
        try:
            entry = self.entry
            del self.entry
        except AttributeError:
            return
        entry.destroy()
        self.drawtext()
        self.canvas.focus_set()


##################################################################
#

class TreeItem:

    """Abstract class representing tree items.

    Methods should typically be overridden, otherwise a default action
    is used.

    """

    def __init__(self):
        """Constructor.  Do whatever you need to do."""

    def GetText(self):
        """Return text string to display."""

    def GetLabelText(self):
        """Return label text string to display in front of text (if any)."""

    expandable = None

    def _IsExpandable(self):
        """Do not override!  Called by TreeNode."""
        if self.expandable is None:
            self.expandable = self.IsExpandable()
        return self.expandable

    def IsExpandable(self):
        """Return whether there are subitems."""
        return 1

    def _GetSubList(self):
        """Do not override!  Called by TreeNode."""
        if not self.IsExpandable():
            return []
        sublist = self.GetSubList()
        if not sublist:
            self.expandable = 0
        return sublist

    def IsEditable(self):
        """Return whether the item's text may be edited."""

    def SetText(self, text):
        """Change the item's text (if it is editable)."""

    def GetIconName(self):
        """Return name of icon to be displayed normally."""

    def GetSelectedIconName(self):
        """Return name of icon to be displayed when selected."""

    def GetSubList(self):
        """Return list of items forming sublist."""

    def OnDoubleClick(self):
        """Called on a double-click on the item."""


##################################################################
#
# Example application

class FileTreeItem(TreeItem):

    """Example TreeItem subclass -- browse the file system."""

    def __init__(self, path, textbox=None):
        self.textbox = ""
        self.path = path
        name, self.ext = os.path.splitext(self.path)
        self.filelisting = []
        if textbox != None:
            self.textbox = textbox
            self.status = textbox.status
        self.imagetypes = ['.gif', '.jpg', '.bmp', '.png', '.tif']

    def GetText(self):
        return os.path.basename(self.path) or self.path

    def IsEditable(self):
        #return os.path.basename(self.path) != ""
        return 0

    def SetText(self, text):
        newpath = os.path.dirname(self.path)
        newpath = os.path.join(newpath, text)
        if os.path.dirname(newpath) != os.path.dirname(self.path):
            return
        try:
            os.rename(self.path, newpath)
            self.path = newpath
        except os.error:
            pass

    def GetIconName(self):
        if not self.IsExpandable():
            name, ext = os.path.splitext(self.path)
            if ext in ['.py']:   #, '.pyc','.pyo']:
                return "python"
            if ext.lower() in self.imagetypes:
                return "image"
            typ = Spiderutils.istextfile(self.path)
            if typ == 1:
                if Spiderutils.isSpiderDocfile(self.path):
                    return "docfile"
                elif Spiderutils.isSpiderBatchfile(self.path):
                    return "procfile"
                elif Spiderutils.isSpiderProcedurefile(self.path):
                    return "procfile"
                else:
                    return "text"
            elif typ == -1:
                return "unknown"
            
            spi = Spiderutils.isSpiderBin(self.path)
            if spi == "image" or spi == "Fourier" or spi == "stack":
                return "spider"
            elif spi == "volume":
                return "volume"
            
            return "binary"   # i.e. a non-spider binary file

    def IsExpandable(self):
        return os.path.isdir(self.path)

    def GetSubList(self):
        try:
            allnames = os.listdir(self.path)
        except os.error:
            return []
        dirlist = []
        filelist = []
        for f in allnames:
            if not SHOWHIDDEN and f[0] == ".":
                continue
            g = os.path.join(self.path,f)  # couldn't find dirs w/o this
            if os.path.isdir(g):
                dirlist.append(f)
            else:
                filelist.append(f)
                
        dirlist.sort() #(lambda a, b: cmp(os.path.normcase(a), os.path.normcase(b)))                
        filelist.sort() #(lambda a, b: cmp(os.path.normcase(a), os.path.normcase(b)))
        names = dirlist + filelist

        sublist = []
        for name in names:
            item = FileTreeItem(os.path.join(self.path, name),
                                textbox=self.textbox)
            sublist.append(item)
        return sublist
    
    def OnDoubleClick(self):
        """Called on a double-click on the icon."""
        self.status.set(self.path)
        
        # Directories: list them in window
        if os.path.isdir(self.path):
            dirmax = int(self.textbox.limits[3].get())
            dirsize = os.path.getsize(self.path)
            if dirsize > dirmax:
                basename = os.path.basename(self.path)
                txt = "%s may contain a very large number of files.\nDisplay anyway?" % (basename)
                if not askyesno("Warning", txt):
                    return
            
            cmd = "ls -lF %s " % self.path
            out = getoutput(cmd)
            filelisting = self.path + "\n" + out
            self.textbox.clear()
            self.textbox.settext(filelisting)

        # view text files in window (sometimes pdfs slip thru)   
        elif self.ext != ".pdf" and Spiderutils.istextfile(self.path):
            # check if html files are sent to browser
            if self.ext == ".html" or self.ext == ".htm":
                browser = self.textbox.limits[4].get()
                if browser:
                    webbrowser.open(self.path)
                    return
                
            textmax = self.textbox.limits[2]
            tmax = int(textmax.get())
            textsize = os.path.getsize(self.path)

            if textsize > tmax:
                basename = os.path.basename(self.path)
                txt = "%s is %d bytes.\nDisplay anyway?" % (basename, textsize)
                if not askyesno("Warning", txt):
                    return
            try:
                fp = open(self.path,'r')
                B = fp.readlines()
            except:
                pass
            fp.close()
            self.textbox.clear()
            for line in B:
                self.textbox.component('text').insert(END, str(line))

        # binaries
        else:
            spidertype = Spiderutils.isSpiderBin(self.path)
            if spidertype != 0:  #== "image":
                infotxt = self.getSpiderInfo(self.path)
                self.textbox.clear()
                self.textbox.component('text').insert(END, infotxt)
                if spidertype == "image":
                    self.putImage(self.path, clear=0)
            
            elif self.ext.lower() in self.imagetypes:
                self.putImage(self.path)
                
            #self.openwith()

    def getSpiderInfo(self, filename):
        info = Spiderutils.spiderInfo(filename)
        if info == 0:
            return ""
        type = info[0]
        dims = info[1]
        infotxt = os.path.basename(filename) + "\n"
        infotxt += "Spider %s file %s\n" % (type, str(dims))
        
        if len(info) > 2:
            stats = info[2]
            infotxt += "max %5.4f, min %5.4f, avg %5.4f, stdev %5.4f\n" % (stats[0],stats[1],stats[2],stats[3])
        return infotxt

    def putImage(self, filename, clear=1):
        if clear:
            self.textbox.clear()
        im = Image.open(filename)
        xsize, ysize = im.size
        xmax = int(self.textbox.limits[0].get())
        ymax = int(self.textbox.limits[1].get())
        if xsize > xmax or ysize > ymax:
            basename = os.path.basename(filename)
            txt = "%s is %d x %d pixels.\nDisplay anyway?" % (basename, xsize, ysize)
            if not askyesno("image exceeds max dimensions", txt):
                return

        if im.format == 'SPIDER':
            im = im.convert2byte()
            photo = ImageTk.PhotoImage(im, palette=256)
        else:
            photo = ImageTk.PhotoImage(im)

        text = self.textbox.component('text')
        
        label = Label(image=photo)
        text.window_create(END, window=label)

        self.textbox.photolabel = label
        self.textbox.labelphoto = photo
              
    def openwith(self):
        " have defaults for certain extensions (pdf, html, etc) " 
        pass
            

##################################################################
#
# A canvas widget with scroll bars and some useful bindings

class ScrolledCanvas:
    def __init__(self, master, **opts):
        if not opts.has_key('yscrollincrement'):
            opts['yscrollincrement'] = 17
        self.master = master
        self.frame = Frame(master)
        self.frame.rowconfigure(0, weight=1)
        self.frame.columnconfigure(0, weight=1)
        self.canvas = Canvas(self.frame, **opts)
        self.canvas.grid(row=0, column=0, sticky="nsew")
        self.vbar = Scrollbar(self.frame, name="vbar")
        self.vbar.grid(row=0, column=1, sticky="nse")
        self.hbar = Scrollbar(self.frame, name="hbar", orient="horizontal")
        self.hbar.grid(row=1, column=0, sticky="ews")
        self.canvas['yscrollcommand'] = self.vbar.set
        self.vbar['command'] = self.canvas.yview
        self.canvas['xscrollcommand'] = self.hbar.set
        self.hbar['command'] = self.canvas.xview
        self.canvas.bind("<Key-Prior>", self.page_up)
        self.canvas.bind("<Key-Next>", self.page_down)
        self.canvas.bind("<Key-Up>", self.unit_up)
        self.canvas.bind("<Key-Down>", self.unit_down)
        #if isinstance(master, Toplevel) or isinstance(master, Tk):
        self.canvas.bind("<Alt-Key-2>", self.zoom_height)
        self.canvas.focus_set()
    def page_up(self, event):
        self.canvas.yview_scroll(-1, "page")
        return "break"
    def page_down(self, event):
        self.canvas.yview_scroll(1, "page")
        return "break"
    def unit_up(self, event):
        self.canvas.yview_scroll(-1, "unit")
        return "break"
    def unit_down(self, event):
        self.canvas.yview_scroll(1, "unit")
        return "break"
    def zoom_height(self, event):
        ZoomHeight.zoom_height(self.master)
        return "break"

##################################################################
#
# main TreeView Class

class TreeViewer:

    def __init__(self, master, icondict, directory=None):
        self.master = master
        self.icondict = icondict
        
        if directory==None:
            self.ddir = os.getcwd()
        else:
            self.ddir = directory

        self.history = [self.ddir]

        # limits for big files, directories
        self.imgxmax = StringVar()
        self.imgymax = StringVar()
        self.textmax = StringVar()
        self.dirmax = StringVar()
        self.htmlVar = IntVar()
        
        self.imgxmax.set(1000)
        self.imgymax.set(1000)
        self.textmax.set(1000000)   # bytes
        self.dirmax.set(MAXDIRSIZE)
        self.htmlVar.set(0)
        self.limits = [self.imgxmax, self.imgymax, self.textmax, self.dirmax, self.htmlVar]

        self.makeMenubar()
        
        self.pw = Pmw.PanedWidget(self.master, orient='horizontal')

        # tree viewer in left pane
        self.lpane = self.pw.add('tree')
        self.sc = ScrolledCanvas(self.lpane, bg="white", highlightthickness=0,
                                 takefocus=1)
        self.sc.frame.pack(expand=1, fill="both", padx = 4, pady = 4)
        self.sc.canvas.icondict = icondict  # make icondict an attribute of the canvas

        # scrolled text in right pane
        self.rpane = self.pw.add('files')
        pane = self.pw.pane('files')  # returns a Frame
        fixedFont = Pmw.logicalfont('Fixed')
        
        self.st = Pmw.ScrolledText(pane,
                                   text_font = fixedFont,
                                   text_wrap='none')
        self.st.component('text').configure(width=80)
        self.st.pack(padx = 4, pady = 4, fill = 'both', expand = 1)
        self.st.limits = self.limits

        self.pw.pack(side='top', expand = 1, fill='both')
        #self.pw.configurepane(self.lpane, size=0.5)
        
        # status bar at the bottom
        self.statusVar = StringVar()
        self.status = Entry(self.master, textvariable=self.statusVar)
        self.status.pack(side='bottom', fill='x', padx=4, pady=2)
        self.st.status = self.statusVar # attach status bar to text box
        
        self.initTree(self.ddir)


    # ------- the menu bar -------
    def makeMenubar(self):
        self.mBar = Frame(self.master, relief='raised', borderwidth=1)
        self.mBar.pack(side='top', fill = 'x')
        self.balloon = Pmw.Balloon(self.master)
        
        # Make the File menu
        Filebtn = Menubutton(self.mBar, text='File', underline=0,
                                 relief='flat')
        Filebtn.pack(side=LEFT, padx=5, pady=5)
        Filebtn.menu = Menu(Filebtn, tearoff=0)
        Filebtn.menu.add_command(label='Directory',
                                 command=self.getDirectory)
        Filebtn.menu.add_command(label='Show Icons',
                                 command=lambda m=self.master: listicons(m))
        Filebtn.menu.add_command(label='Clear',
                                 command=self.clearCanvas)
        Filebtn.menu.add_command(label='Options',
                                 command=self.getOptions)
        Filebtn.menu.add_separator()
        Filebtn.menu.add_command(label='Quit', underline=0,
                                     command=self.master.quit)
        Filebtn['menu'] = Filebtn.menu

        # Entry field for current directory
        self.dirbut = Button(self.mBar, text="Directory:", command=self.getDirectory)
        self.dirbut.pack(side='left',padx=2)
        self.entry = Pmw.ComboBox(self.mBar,scrolledlist_items=self.history,
                                  dropdown=1)
        entryfield = self.entry.component('entryfield').component('entry')
        entryfield.configure(width=48)
        self.entry.pack(side='left')
        self.entry.selectitem(self.history[0], setentry=1)
        
        entryfield.bind('<Return>', self.newDirectory)
        entryfield.bind('<Double-Button-1>', self.newDirectory)

        # Button to go up one directory
        updir = self.icondict['updir']
        Dirbtn = Button(self.mBar, image=updir, command=self.upDirectory)
        Dirbtn.pack(side='left', padx=4,pady=2)

    def newDirectory(self, event=None):
        if event != None:
            newdir = self.entry.get()
            if not os.path.exists(newdir):
                print "directory %s not found" % newdir
                return
            os.chdir(newdir)
            self.ddir = os.getcwd()
    
        if self.ddir not in self.history:
            self.history = [self.ddir] + self.history
            self.entry.component('scrolledlist').insert(0, self.ddir)
            self.entry.selectitem(self.ddir)
        self.clearCanvas()
        self.initTree(self.ddir)

    def initTree(self, directory):
        self.ftreeitem = FileTreeItem(path=directory, textbox=self.st)
        self.node = TreeNode(self.sc.canvas, None, self.ftreeitem)
        self.node.expand()

    def clearCanvas(self):
        allitems = self.sc.canvas.find_all()
        for item in allitems:
            self.sc.canvas.delete(item)
        if hasattr(self, 'ftreeitem'):
            del(self.ftreeitem)
        self.node.destroy()

    def getDirectory(self):
        newdir = askdirectory(initialdir=self.ddir, mustexist=1)
        if type(newdir) != type("string"):
            newdir = str(newdir)
        if newdir != None and newdir != "" and os.path.exists(newdir):
            self.ddir = newdir
            self.newDirectory()

    def upDirectory(self):
        os.chdir("..")
        self.ddir = os.getcwd()
        self.newDirectory()

    def getOptions(self):
        win = Toplevel(self.master)
        win.title('Options')
        f1 = Frame(win)
        f1.pack(side='top', fill='both', expand=1)
        width = 9
        imglbl = Label(f1, text="Max image size:")
        imgxentry = Entry(f1, textvariable = self.imgxmax, width=width)
        imglbl2 = Label(f1, text=" x ")
        imgyentry = Entry(f1, textvariable = self.imgymax, width=width)
        imglbl.grid(row=0, column=0, sticky="e")
        imgxentry.grid(row=0, column=1, sticky="ew")
        imglbl2.grid(row=0, column=2, sticky="e")
        imgyentry.grid(row=0, column=3, sticky="ew")

        txtlbl = Label(f1, text="Max text file:")
        txtentry = Entry(f1, textvariable = self.textmax, width=width)
        txtlbl.grid(row=1, column=0, sticky="e")
        txtentry.grid(row=1, column=1, sticky="ew")
        
        dirlbl = Label(f1, text="Max directory size:")
        direntry = Entry(f1, textvariable = self.dirmax, width=width)
        dirlbl.grid(row=2, column=0, sticky="e")
        direntry.grid(row=2, column=1, sticky="ew")

        f2 = Frame(win)
        f2.pack(side='top', fill='both', expand=1)
        cb = Checkbutton(f2, text="Display html files in browser",
                         variable=self.htmlVar)
        cb.pack(anchor='w', side='bottom', padx=5,pady=5, fill=X, expand=1)

        ok = Button(win, text='Done', command=win.destroy)
        ok.pack(side='bottom', anchor='se', padx=2, pady=2)
# ===========================================================================
if __name__ == '__main__':
    
    if  len(sys.argv[1:]) > 0:
        ddir = sys.argv[1]
        if not os.path.exists(ddir):
            print "cannot find %s" % ddir
            sys.exit()
        else:
            os.chdir(ddir)
            ddir = os.getcwd()
    else:
        ddir = os.getcwd()

    root = Tk()
    root.title("TreeView")
    icondict = makeIcons()
    tv = TreeViewer(root,icondict,ddir)
    root.mainloop()
