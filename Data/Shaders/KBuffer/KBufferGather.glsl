
#include "KBufferHeader.glsl"
#include "ColorPack.glsl"
#include "TiledAddress.glsl"

#define REQUIRE_INVOCATION_INTERLOCK

out vec4 fragColor;

void gatherFragment(vec4 color)
{
    if (color.a < 0.001) {
        discard;
    }

	uint x = uint(gl_FragCoord.x);
	uint y = uint(gl_FragCoord.y);
	uint pixelIndex = addrGen(uvec2(x,y));
	// Fragment index (in nodes buffer):
	uint index = MAX_NUM_NODES*pixelIndex;

	FragmentNode frag;
	frag.color = packColorRGBA(color);
	frag.depth = gl_FragCoord.z;

	memoryBarrierBuffer();

	// Use insertion sort to insert new fragment
	uint numFragments = numFragmentsBuffer[pixelIndex];
	for (uint i = 0; i < numFragments; i++)
	{
		if (frag.depth < nodes[index].depth)
		{
			FragmentNode temp = frag;
			frag = nodes[index];
			nodes[index] = temp;
		}
		index++;
	}
	
	// Store the fragment at the end of the list if capacity is left
	if (numFragments < MAX_NUM_NODES) {
		//atomicAdd(numFragmentsBuffer[pixelIndex], 1);
		numFragmentsBuffer[pixelIndex]++;
		nodes[index] = frag;
	} else {
    	// Blend with last fragment
		vec4 colorDst = unpackColorRGBA(nodes[index-1].color);
		vec4 colorSrc = unpackColorRGBA(frag.color);

		vec4 colorOut;
		colorOut.rgb = colorDst.a * colorDst.rgb + (1.0 - colorDst.a) * colorSrc.a * colorSrc.rgb;
        colorOut.a = colorDst.a + (1.0 - colorDst.a) * colorSrc.a;
        //colorOut.a = colorSrc.a + colorDst.a * (1.0 - colorSrc.a);
        //colorOut.rgb = colorSrc.rgb * colorSrc.a + colorDst.rgb * colorDst.a * (1.0 - colorSrc.a);

    	nodes[index-1].color = packColorRGBA(vec4(colorOut.rgb / colorOut.a, colorOut.a));
	}

	fragColor = vec4(0.0, 0.0, 0.0, 0.0);
}