module RayTraceEllipsoid

using CoordinateTransformations, StaticArrays, UnitfulAngles
import LinearAlgebra: normalize, ⋅

export Vec, Ray, Ellipsoid, Interface, OpticUnit, raytrace!, advance!, bend!

"""
    Vec = SVector{3,Float64}

Points and directions are just a point in 3D space best described as a static vector, `SVector`. `Vec` is an alias for that.
"""
const Vec = SVector{3,Float64}

"""
    Ray(orig::Vec, dir::Vec)

The main Ray type with a ray origin, `orig`, and direction, `dir`. The ray's direction gets normalized.
"""
mutable struct Ray
    orig::Vec
    dir::Vec
    Ray(o::Vec, d::Vec) = new(o, normalize(d))
end

Ray() = Ray(Vec(0,0,0), Vec(1,0,0))

"""
    Ellipsoid(c::Vec, r::Vec, dir::Vec, open::Float64)

    An ellipsoid with a center, `c`, and radii, `r`, as well as a direction (gets automatically normalized), `dir`, and an opening angle, `open`, creating a dome (or window), that the ellipsoid is defined in. Note that `open` is the angle between the dome's edge and the direction of the dome (so actually half the opening angle) and is defined in **some angular units** (using UnitfulAngles, for example: u"°").

`Ellipsoid` has 6 additional fields all relating to various spatial transformations that convert the ellipsoid to a unit-sphere and back again. These are all `CoordinateTransformations`.

# Examples
For an ellipsoid upwards-pointing hemisphere with a center at (1,2,3), and radii (4,5,6):
```jldoctest
julia> Ellipsoid(Vec(1,2,3), Vec(4,5,6), Vec(0,0,1), 0.0)
Rayden.Ellipsoid([1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [0.0, 0.0, 1.0], 0.0, Translation(-1.0, -2.0, -3.0), LinearMap([0.25 0.0 0.0; 0.0 0.2 0.0; 0.0 0.0 0.166667]), AffineMap([0.25 0.0 0.0; 0.0 0.2 0.0; 0.0 0.0 0.166667], [-0.25, -0.4, -0.5]), Translation(1.0, 2.0, 3.0), LinearMap([4.0 0.0 0.0; 0.0 5.0 0.0; 0.0 0.0 6.0]), AffineMap([4.0 0.0 0.0; 0.0 5.0 0.0; 0.0 0.0 6.0], [1.0, 2.0, 3.0]))
```
"""
struct Ellipsoid
    c::Vec
    r::Vec
    dir::Vec
    open::Float64 # cos(α), where α is half the opening angle of the dome
    # all of the following are transformations
    center::Translation{Vec} # translate the ellipsoid to zero
    scale::LinearMap{SDiagonal{3,Float64}}
    center_scale::AffineMap{SDiagonal{3,Float64},Vec} # translate and scale to a unit-sphere
    uncenter::Translation{Vec}
    unscale::LinearMap{SDiagonal{3,Float64}}
    uncenter_unscale::AffineMap{SDiagonal{3,Float64},Vec}
    function Ellipsoid(c::Vec, r::Vec, dir::Vec, α)
        uncenter = Translation(c)
        unscale = LinearMap(SDiagonal(r))
        center = inv(uncenter)
        scale = inv(unscale)
        center_scale = scale∘center
        uncenter_unscale = inv(center_scale)
        new(c, r, normalize(dir), cos(α), center, scale, center_scale, uncenter, unscale, uncenter_unscale)
    end
end

"""
    distance(orig::Vec, dir::Vec)

Return the two distances between a point with origin, `orig`, and direction, `dir`, and the two (potentially identical) intersection points with a unit-sphere. 
"""
function distance(orig::Vec, dir::Vec)
    b = -orig⋅dir
    disc = b^2 - orig⋅orig + 1
    if disc ≥ 0
        d = sqrt(disc)
        t2 = b + d
        if t2 ≥ 0
            t1 = b - d
            return t1 > 0 ? (t1, t2) : (Inf, t2)
        end
    end
    return (Inf, Inf)
end

"""
    advance!(r::Ray, s::Ellipsoid)

Find the shortest point of intersection that is within the ellipsoid's dome and reassign the origin of the ray. Returns failure of the intersection.
"""
function advance!(r::Ray, s::Ellipsoid)
    # move the ray's origin to the intersection point that is within the ellipsoid's dome, and return failure
    orig = s.center_scale(r.orig) # transform the ray's origin according to the ellipsoid
    dir = normalize(s.scale(r.dir)) # scale the ray's direction as well
    ls = distance(orig, dir)
    for l in ls
        if !isinf(l)
            o = orig + l*dir
            p = s.unscale(o)
            cosα = s.dir⋅normalize(p)
            if cosα > s.open
                r.orig = s.uncenter(p)
                return false
            end
        end
    end
    return true
end

"""
    Interface(normal::AffineMap, n::Float64)

Build an optical interface from a AffineMap that transforms a point on the ellipsoid of the interface to the normal at that point, `normal`, and the refractive index ratio between the inside and the outside of the ellipsoid, `n`.
"""
struct Interface
    normal::AffineMap{SDiagonal{3, Float64}, SVector{3,Float64}}
    n::Float64
    n2::Float64
    Interface(normal::AffineMap{SDiagonal{3,Float64},SVector{3,Float64}}, n::Float64) = new(normal, n, n^2)
end

"""
    OpticUnit(body::Ellipsoid, interface::Interface, register::Bool, name::String)

Build an optical unit. `register` indicates whether this unit should register intersection points (thus functions as a retina).
"""
struct OpticUnit
    body::Ellipsoid
    interface::Interface
    register::Bool
    name::String
end


"""
    OpticUnit(body::Ellipsoid, pointin::Bool, n::Float64, register::Bool, name::String)

Convenience function to build optical units. Build an optical unit depending on if the normal should be pointing in or out, `pointin`. The correct AffineMap transformation will be automatically calculated.
"""
function OpticUnit(body::Ellipsoid, pointin::Bool, n::Float64, register::Bool, name::String)
    i = ifelse(pointin, -1.0, 1.0)
    dir = LinearMap(SDiagonal{3, Float64}(i, i, i))
    normal = dir∘body.scale∘body.scale∘body.center
    interface = Interface(normal, n)
    return OpticUnit(body, interface, register, name)
end


"""
    bend!(r::Ray, i::Interface)

Refract or reflect a ray with an interface. Update the direction of the ray. Returns if event failed, which is always `false` (see `raytrace!` for details why that is so).
"""
function bend!(r::Ray, i::Interface)
    i.n == 1 && return false # we're done cause the refractive indices are the same
    N = normalize(i.normal(r.orig))
    a = -r.dir⋅N
    b = i.n2*(1 - a^2)
    dir = if b ≤ 1 # refract or reflect? refract!
        i.n*r.dir + (i.n*a - sqrt(1 - b))*N
    else # reflect!
        r.dir + 2a*N
    end
    r.dir = normalize(dir)
    return false
end

"""
    raytrace!(r::Ray, c::OpticUnit)

Advance a ray to the intersection point with an ellipsoid. If the intersection was successful, bend the ray. Updates the ray accordingly. Returns intersection failure.
"""
raytrace!(r::Ray, c::OpticUnit) = advance!(r, c.body) || bend!(r, c.interface)

end #module
