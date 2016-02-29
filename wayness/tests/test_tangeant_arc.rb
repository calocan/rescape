#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Test_Tangeant_Arc
  def test(offset_point, vector1, vector2, grade)
    if (grade==0)
      return []
    end

    point1 = offset_point.transform(vector1)
    point2 = offset_point.transform(vector2)
    mid_point = Geom::Point3d.linear_combination(0.5, point1, 0.5, point2)
    results = [point1,point2].map {|point|
      center_line_mid_point = Geom::Point3d.linear_combination(0.5, mid_point, 0.5, offset_point)
      point_to_vertex_mid_point = Geom::Point3d.linear_combination(0.5, point, 0.5, offset_point)
      [point] + test(point_to_vertex_mid_point, point_to_vertex_mid_point.vector_to(point), point_to_vertex_mid_point.vector_to(center_line_mid_point), grade-1)+[center_line_mid_point]
    }
    results[0] + results[1].reverse
  end
   def make_corrections(offset_point, vector1, vector2)
    if (vector1.angle_between(vector2) < 90.degrees)
      point1 = offset_point.transform(vector1)
      point2 = offset_point.transform(vector2)
      distance1_2 = point1.distance(point2)
      radius = Math.sqrt((distance1_2**2) / 2)
      puts radius
      angle_to_circle_center = Math.acos(distance1_2/2 / radius)
      # Translate point1 by the radius toward point2 then rotate it to the circle center point
      vector1_2 = point1.vector_to(point2)
      vector1_2.length = radius
      puts angle_to_circle_center
      puts vector1.cross(vector2)
      rotation =  Geom::Transformation.rotation(point1, vector2.cross(vector1), angle_to_circle_center)
      transformation = rotation *
          Geom::Transformation.translation(vector1_2)
      circle_center_point = point1.transform(transformation)
      Sketchup.active_model.entities.add_line(circle_center_point, point1)
    end
   end

  def create_arc pt_a, pt_b, pt_c

    # Define the points and vectors
    a = Geom::Point3d.new pt_a
    b = Geom::Point3d.new pt_b
    c = Geom::Point3d.new pt_c
    ab = b - a; bc = c - b; ca = a - c

    # Find the vector lengths
    ab_length = ab.length
    bc_length = bc.length
    ca_length = ca.length

    # Find the cross product of AB and BC
    cross = ab * bc
    cross_length = cross.length
    denom = 2 * cross_length**2

    # Find the radius
    radius = (ab_length*bc_length*ca_length)/(2*cross_length)

    # Find the center
    alpha = -1 * bc_length**2 * (ab.dot ca)/denom
    beta = -1 * ca_length**2 * (ab.dot bc)/denom
    gamma = -1 * ab_length**2 * (ca.dot bc)/denom
    o = a.transform alpha
    o.transform! (b.transform beta)
    o.transform! (c.transform gamma)

    # Compute the normal vector
    normal = ab * bc; normal.normalize!

    # Determine the angles between the points
    oa = a - o; ob = b - o; oc = c - o
    aob = oa.angle_between ob
    aoc = oa.angle_between oc
    boc = ob.angle_between oc

    # Check for correct angles
    if aoc < boc
      boc = 2 * Math::PI - boc
    elsif aoc < aob
      aob = 2 * Math::PI - aob
    end

    # Create the two arcs
    ents = Sketchup.active_model.entities
    arc_1 = ents.add_arc o, oa, normal, radius, 0, aob
    arc_2 = ents.add_arc o, ob, normal, radius, 0, boc
    arc_1 += arc_2
  end
end