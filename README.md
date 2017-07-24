# RayTraceEllipsoid

[![Build status](https://ci.appveyor.com/api/projects/status/voutf74a40lh511f?svg=true)](https://ci.appveyor.com/project/juliaGeometry/raytraceellipsoid-jl) [![Build Status](https://travis-ci.org/juliaGeometry/RayTraceEllipsoid.jl.svg?branch=master)](https://travis-ci.org/juliaGeometry/RayTraceEllipsoid.jl)

[![Coverage Status](https://coveralls.io/repos/juliaGeometry/RayTraceEllipsoid.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/juliaGeometry/RayTraceEllipsoid.jl?branch=master) [![codecov.io](http://codecov.io/github/juliaGeometry/RayTraceEllipsoid.jl/coverage.svg?branch=master)](http://codecov.io/github/juliaGeometry/RayTraceEllipsoid.jl?branch=master)

This Julia package allows for geometric ray tracing with ellipsoids (actually domes shaped as ellipsoids). It includes intersection and refraction/reflection of rays with arbitrary ellipsoids. It accomplishes that in about 100 lines of code thanks to heavy use of `CoordinateTransformations.jl` and `StaticArrays.jl`.

These ellipsoid-domes are defined with `Ellipsoid` (see details with `help?> Ellipsoid`). The normal and refractive indices are defined within the `Interface` type. These two are baked into a single `OpticUnit`.

`Ray`s `advance!` to intersect with the `Ellipsoid`s and `bend!` at the `Interface`s. The `raytrace!` function includes these two actions, taking in a `Ray` and an `OpticUnit`, updating the location and direction of the ray.

## Todo
- add the `Angles.jl` package to improve how users input cos(α)
- add rotated ellipsoids
- add more shapes, so it's not only `RayTrace**Ellipsoid**`
