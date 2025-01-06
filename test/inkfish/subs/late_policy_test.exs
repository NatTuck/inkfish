defmodule Inkfish.LatePolicyTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.LocalTime
  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Uploads.Upload
  alias Inkfish.Grades

  def create_assignment(hours_due, hd) do
    asgn = insert(:assignment, due: LocalTime.in_hours(hours_due), hard_deadline: hd)
    _gc = insert(:grade_column, assignment: asgn)
    asgn
  end

  def create_sub_and_grade(asgn) do
    sub_attrs = params_with_assocs(:sub, assignment: asgn)
    assert {:ok, %Sub{} = sub} = Subs.create_sub(sub_attrs)
    sub = Subs.get_sub_path!(sub.id)

    gcol = hd(sub.assignment.grade_columns)

    grade_attrs = %{
      sub_id: sub.id,
      grade_column_id: gcol.id,
      score: Decimal.new("25.0")
    }

    {:ok, grade} = Grades.create_grade(grade_attrs)
    %Sub{sub | grades: [grade]}
  end

  describe "late penalties" do
    setup do
      base = Upload.upload_base()

      if String.length(base) > 10 && base =~ ~r/test/ do
        File.rm_rf!(base)
      end

      :ok
    end

    test "no penalty if not late, standard" do
      asgn = create_assignment(4, false)
      sub = create_sub_and_grade(asgn)
      assert sub.active

      {sc, lp} = Subs.calc_score_and_late_penalty(sub)
      assert Decimal.equal?(sc, Decimal.new("25.0"))
      assert Decimal.equal?(lp, Decimal.new("0.0"))
    end

    test "no penalty if not late, hard deadline" do
      asgn = create_assignment(4, true)
      sub = create_sub_and_grade(asgn)
      assert sub.active

      {sc, lp} = Subs.calc_score_and_late_penalty(sub)
      assert Decimal.equal?(sc, Decimal.new("25.0"))
      assert Decimal.equal?(lp, Decimal.new("0.0"))
    end

    test "penalty if late, standard" do
      asgn = create_assignment(-4, false)
      sub = create_sub_and_grade(asgn)
      assert sub.active

      {sc, lp} = Subs.calc_score_and_late_penalty(sub)
      assert Decimal.equal?(sc, Decimal.new("23.0"))
      assert Decimal.equal?(lp, Decimal.new("2.0"))
    end

    test "penalty if late, hard deadline" do
      asgn = create_assignment(-4, true)
      sub = create_sub_and_grade(asgn)
      assert sub.active

      {sc, lp} = Subs.calc_score_and_late_penalty(sub)
      assert Decimal.equal?(sc, Decimal.new("0.0"))
      assert Decimal.equal?(lp, Decimal.new("50.0"))
    end
  end
end
