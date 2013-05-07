#import "GPUImageFilter.h"

@interface GPUImageCrosshairGenerator : GPUImageFilter
{
    GLint crosshairWidthUniform, crosshairColorUniform;
}

typedef struct _Color4F {
    GLfloat r;
    GLfloat g;
    GLfloat b;
    GLfloat a;
} Color4F[64];

// The width of the displayed crosshairs, in pixels. Currently this only works well for odd widths. The default is 5.
@property(readwrite, nonatomic) CGFloat crosshairWidth;

// The color of the crosshairs is specified using individual red, green, and blue components (normalized to 1.0). The default is green: (0.0, 1.0, 0.0).
- (void)setCrosshairColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent;

// Rendering
- (void)renderCrosshairsFromArray:(GLfloat *)crosshairCoordinates count:(NSUInteger)numberOfCrosshairs colors:(GLfloat *) colors frameTime:(CMTime)frameTime;

@end
