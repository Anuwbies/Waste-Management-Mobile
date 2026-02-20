import turtle
screen = turtle.Screen()
turtle.bgcolor("black")

t = turtle.Turtle()
t.shape("turtle")
t.color("blue")
t.speed(12)


# sides = 18
# length = 100 
# angle = 360 / sides

# for x in range(sides):
#     t.forward(length)
#     t.left(angle)

colors = ["red", "yellow", "blue", "green", "orange", "purple"]

for i in range(360):
    t.color(colors[i % 6])
    t.forward(i * 1.5)
    t.left(59)
    t.width(i / 100 + 1)
screen.exitonclick()