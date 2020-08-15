Hi,

Here is my rendering test for LiveSurface.  

The high-level structure of the code is:

*MainView.swift: a simple swift NSView that is instantiated from the interface builder.  An LGGraphicsView is added to this view during initialization.

*LGGraphicsView.m: This is a MTKView that uses Metal for rendering.  It has the bulk of the code.  The actual rendering setup is pretty simple.  The images are just layered in a basic orthographic view.  Some scaling is done to maintain the correct aspect ratios.

*MetalSource.metal: There are two sets of shaders in this file.  One is for rendering the scene and uses the mask and the “shading” for reflection.  The other is for rendering the artboard with a poster and a normal map to give it some texture.

I definitely had some ideas to expand this little viewer but I ran out of time.

Please reach out if you have any questions.  Thanks!

-Zach

P.S. I am living on the edge with the Big Sur Beta and the Beta version of XCode.  Hopefully that doesn't cause issues if you actually try to load this project.  If you do have issues, please let me know and I can help debug.