using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace RubyRun3D.Core
{
    /// <summary>Original low-poly placeholder art. Every root can be replaced by a licensed prefab.</summary>
    public static class StylizedFactory
    {
        static readonly Dictionary<Color, Material> Materials = new();
        static Mesh sphereMesh;
        static Mesh coneMesh;
        static Mesh boxMesh;

        public static Material Material(Color color, float metallic = 0, float smoothness = 0.25f)
        {
            if (Materials.TryGetValue(color, out var cached)) return cached;
            var shader = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
            var material = new Material(shader) { color = color, enableInstancing = true };
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            Materials[color] = material;
            return material;
        }

        public static GameObject Part(string name, Transform parent, Mesh mesh, Vector3 localPosition,
            Vector3 scale, Color color, Quaternion? rotation = null)
        {
            var part = new GameObject(name);
            part.transform.SetParent(parent, false);
            part.transform.localPosition = localPosition;
            part.transform.localRotation = rotation ?? Quaternion.identity;
            part.transform.localScale = scale;
            part.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = part.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = Material(color);
            renderer.shadowCastingMode = ShadowCastingMode.On;
            renderer.receiveShadows = true;
            return part;
        }

        public static GameObject CreateRuby(Transform parent, Color fur, Color accent)
        {
            var root = new GameObject("Ruby_ReplaceableVisual");
            root.transform.SetParent(parent, false);
            var dark = Color.Lerp(fur, Color.black, 0.28f);
            Part("Body", root.transform, Sphere(), new Vector3(0, .72f, 0), new Vector3(.52f, .72f, .5f), fur);
            Part("Head", root.transform, Sphere(), new Vector3(0, 1.52f, .05f), new Vector3(.68f, .62f, .62f), fur);
            Part("Muzzle", root.transform, Sphere(), new Vector3(0, 1.36f, .55f), new Vector3(.39f, .3f, .38f), accent);
            Part("EarL", root.transform, Cone(), new Vector3(-.36f, 2.02f, 0), new Vector3(.25f, .54f, .25f), dark);
            Part("EarR", root.transform, Cone(), new Vector3(.36f, 2.02f, 0), new Vector3(.25f, .54f, .25f), dark);
            Part("Tail", root.transform, Cone(), new Vector3(0, .78f, -.75f), new Vector3(.42f, 1.15f, .42f), fur,
                Quaternion.Euler(68, 0, 0));
            Part("TailTip", root.transform, Sphere(), new Vector3(0, 1.08f, -1.13f), new Vector3(.29f, .35f, .29f), accent);
            Part("EyeL", root.transform, Sphere(), new Vector3(-.23f, 1.65f, .54f), Vector3.one * .09f, new Color(.05f,.06f,.09f));
            Part("EyeR", root.transform, Sphere(), new Vector3(.23f, 1.65f, .54f), Vector3.one * .09f, new Color(.05f,.06f,.09f));
            Part("Nose", root.transform, Sphere(), new Vector3(0, 1.38f, .86f), Vector3.one * .11f, dark);
            AddLimbs(root.transform, fur);
            return root;
        }

        public static GameObject CreateSoldier(Transform parent, Color uniform)
        {
            var root = new GameObject("Soldier_ReplaceableVisual");
            root.transform.SetParent(parent, false);
            Part("Body", root.transform, Sphere(), new Vector3(0,.6f,0), new Vector3(.34f,.53f,.3f), uniform);
            Part("Head", root.transform, Sphere(), new Vector3(0,1.24f,0), Vector3.one*.34f, new Color(.92f,.72f,.52f));
            Part("Helmet", root.transform, Sphere(), new Vector3(0,1.42f,-.01f), new Vector3(.39f,.25f,.39f), Color.Lerp(uniform,Color.black,.2f));
            Part("Blaster", root.transform, Box(), new Vector3(.29f,.77f,.38f), new Vector3(.12f,.12f,.55f), new Color(.15f,.18f,.24f));
            AddLimbs(root.transform, uniform, .72f);
            return root;
        }

        public static GameObject CreateEnemy(Transform parent, Data.EnemyArchetype type)
        {
            var root = new GameObject($"{type}_ReplaceableVisual");
            root.transform.SetParent(parent, false);
            var color = type switch {
                Data.EnemyArchetype.Heavy => new Color(.48f,.15f,.55f),
                Data.EnemyArchetype.Ranged => new Color(.85f,.38f,.12f),
                Data.EnemyArchetype.Boss => new Color(.18f,.3f,.22f),
                _ => new Color(.73f,.17f,.2f)
            };
            var size = type == Data.EnemyArchetype.Boss ? 2.2f : type == Data.EnemyArchetype.Heavy ? 1.35f : 1f;
            Part("Torso", root.transform, Sphere(), new Vector3(0,.72f*size,0), new Vector3(.48f,.68f,.4f)*size, color);
            Part("Head", root.transform, Sphere(), new Vector3(0,1.5f*size,0), Vector3.one*.48f*size, Color.Lerp(color,Color.white,.12f));
            Part("HornL", root.transform, Cone(), new Vector3(-.28f*size,1.98f*size,0), Vector3.one*.22f*size, Color.Lerp(color,Color.black,.3f));
            Part("HornR", root.transform, Cone(), new Vector3(.28f*size,1.98f*size,0), Vector3.one*.22f*size, Color.Lerp(color,Color.black,.3f));
            Part("EyeL", root.transform, Sphere(), new Vector3(-.17f*size,1.58f*size,.42f*size), Vector3.one*.08f*size, Color.yellow);
            Part("EyeR", root.transform, Sphere(), new Vector3(.17f*size,1.58f*size,.42f*size), Vector3.one*.08f*size, Color.yellow);
            AddLimbs(root.transform, color, size);
            return root;
        }

        static void AddLimbs(Transform root, Color color, float scale = 1f)
        {
            Part("LegL", root, Sphere(), new Vector3(-.2f,.2f,0)*scale, new Vector3(.16f,.34f,.16f)*scale, color);
            Part("LegR", root, Sphere(), new Vector3(.2f,.2f,0)*scale, new Vector3(.16f,.34f,.16f)*scale, color);
            Part("ArmL", root, Sphere(), new Vector3(-.42f,.75f,0)*scale, new Vector3(.13f,.4f,.13f)*scale, color,
                Quaternion.Euler(0,0,-18));
            Part("ArmR", root, Sphere(), new Vector3(.42f,.75f,0)*scale, new Vector3(.13f,.4f,.13f)*scale, color,
                Quaternion.Euler(0,0,18));
        }

        public static GameObject CreateProp(string name, Transform parent, Vector3 position, int variant)
        {
            var root = new GameObject(name);
            root.transform.SetParent(parent, false);
            root.transform.localPosition = position;
            if (variant % 3 == 0)
            {
                Part("Trunk", root.transform, Box(), new Vector3(0,1,0), new Vector3(.35f,2,.35f), new Color(.34f,.18f,.09f));
                Part("CrownA", root.transform, Sphere(), new Vector3(0,2.45f,0), new Vector3(1.25f,1.4f,1.25f), new Color(.17f,.52f,.26f));
                Part("CrownB", root.transform, Sphere(), new Vector3(.55f,2.25f,.1f), Vector3.one*.8f, new Color(.24f,.65f,.31f));
            }
            else if (variant % 3 == 1)
            {
                Part("Rock", root.transform, Sphere(), new Vector3(0,.35f,0), new Vector3(.75f,.55f,.65f), new Color(.4f,.46f,.48f), Quaternion.Euler(8,20,4));
            }
            else
            {
                Part("Bush", root.transform, Sphere(), new Vector3(0,.38f,0), new Vector3(.8f,.55f,.7f), new Color(.13f,.58f,.3f));
                Part("Flowers", root.transform, Sphere(), new Vector3(.25f,.72f,.1f), Vector3.one*.12f, new Color(1f,.55f,.68f));
            }
            return root;
        }

        public static Mesh Sphere() => sphereMesh ??= CreateSphere(12, 8);
        public static Mesh Cone() => coneMesh ??= CreateCone(10);
        public static Mesh Box() => boxMesh ??= CreateBox();

        static Mesh CreateSphere(int columns, int rows)
        {
            var vertices = new List<Vector3>(); var normals = new List<Vector3>(); var triangles = new List<int>();
            for (var y=0;y<=rows;y++) for(var x=0;x<=columns;x++)
            {
                var v=(float)y/rows; var u=(float)x/columns;
                var phi=v*Mathf.PI; var theta=u*Mathf.PI*2;
                var p=new Vector3(Mathf.Sin(phi)*Mathf.Cos(theta),Mathf.Cos(phi),Mathf.Sin(phi)*Mathf.Sin(theta));
                vertices.Add(p); normals.Add(p.normalized);
            }
            for(var y=0;y<rows;y++) for(var x=0;x<columns;x++)
            {
                var i=y*(columns+1)+x; triangles.Add(i); triangles.Add(i+columns+1); triangles.Add(i+1);
                triangles.Add(i+1); triangles.Add(i+columns+1); triangles.Add(i+columns+2);
            }
            var mesh=new Mesh { name="RubyRun_LowPolySphere" }; mesh.SetVertices(vertices); mesh.SetNormals(normals); mesh.SetTriangles(triangles,0); mesh.RecalculateBounds(); return mesh;
        }

        static Mesh CreateCone(int sides)
        {
            var vertices=new List<Vector3>{new(0,1,0),new(0,0,0)}; var triangles=new List<int>();
            for(var i=0;i<sides;i++){var a=i*Mathf.PI*2/sides;vertices.Add(new(Mathf.Cos(a),0,Mathf.Sin(a)));}
            for(var i=0;i<sides;i++){var n=2+(i+1)%sides;var c=2+i;triangles.Add(0);triangles.Add(n);triangles.Add(c);triangles.Add(1);triangles.Add(c);triangles.Add(n);}
            var mesh=new Mesh{name="RubyRun_Cone"};mesh.SetVertices(vertices);mesh.SetTriangles(triangles,0);mesh.RecalculateNormals();mesh.RecalculateBounds();return mesh;
        }

        static Mesh CreateBox()
        {
            var v=new[]{new Vector3(-.5f,-.5f,-.5f),new(.5f,-.5f,-.5f),new(.5f,.5f,-.5f),new(-.5f,.5f,-.5f),new(-.5f,-.5f,.5f),new(.5f,-.5f,.5f),new(.5f,.5f,.5f),new(-.5f,.5f,.5f)};
            var t=new[]{0,2,1,0,3,2,4,5,6,4,6,7,0,4,7,0,7,3,1,2,6,1,6,5,3,7,6,3,6,2,0,1,5,0,5,4};
            var mesh=new Mesh{name="RubyRun_Box"};mesh.vertices=v;mesh.triangles=t;mesh.RecalculateNormals();mesh.RecalculateBounds();return mesh;
        }
    }
}
