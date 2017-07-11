using Base.Test, Rayden

r = Ray()
@test r.dir == Vec(1,0,0)

r = Ray(Vec(1, 2, 10), Vec(0, 0, -1))
s = Ellipsoid(Vec(1, 2, 2), Vec(5, 4, 2), Vec(0, 0, 1), cosd(90))
a = advance!(r, s)
@test norm(s.center(r.orig)) ≈ s.r[3]

r = Ray(Vec(1, 2, 10), Vec(0, 0, 1))
a = advance!(r, s)
@test a

r = Ray(Vec(1, 2, 10), Vec(0, 0, -1))
s = Ellipsoid(Vec(1, 2, 2), Vec(5, 4, 2), Vec(0, 0, -1), cosd(90))
a = advance!(r, s)
@test s.center(r.orig)[3] ≈ -s.r[3]

r = Ray(Vec(1, 2, 10), Vec(-.3, .4, -1))
dir_org = deepcopy(r.dir)
s = Ellipsoid(Vec(1, 2, 2), Vec(5, 4, 2), Vec(0, 0, -1), cosd(90))
a = advance!(r, s)
ou = OpticUnit(s, true, 1., true, "a")
bend!(r, ou.interface)
@test dir_org ≈ r.dir

r = Ray(Vec(1, 2, 10), Vec(-.3, .4, -1))
dir_org = deepcopy(r.dir)
s = Ellipsoid(Vec(1, 2, 2), Vec(5, 4, 2), Vec(0, 0, -1), cosd(90))
a = advance!(r, s)
ou = OpticUnit(s, true, 1.5, true, "a")
bend!(r, ou.interface)
@test dir_org ≠ r.dir

r = Ray(Vec(1, 2, 10), Vec(0, 0, -1))
dir_org = deepcopy(r.dir)
s = Ellipsoid(Vec(1, 2, 2), Vec(5, 4, 2), Vec(0, 0, 1), cosd(90))
ou = OpticUnit(s, false, 1., true, "a")
a = raytrace!(r, ou)
@test norm(s.center(r.orig)) ≈ s.r[3]
@test dir_org ≈ r.dir
